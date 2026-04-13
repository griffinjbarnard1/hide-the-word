#!/usr/bin/env python3

import json
import re
import sys
import urllib.request
from pathlib import Path


BOOKS = [
    ("Genesis", "genesis"),
    ("Exodus", "exodus"),
    ("Leviticus", "leviticus"),
    ("Numbers", "numbers"),
    ("Deuteronomy", "deuteronomy"),
    ("Joshua", "joshua"),
    ("Judges", "judges"),
    ("Ruth", "ruth"),
    ("1 Samuel", "1samuel"),
    ("2 Samuel", "2samuel"),
    ("1 Kings", "1kings"),
    ("2 Kings", "2kings"),
    ("1 Chronicles", "1chronicles"),
    ("2 Chronicles", "2chronicles"),
    ("Ezra", "ezra"),
    ("Nehemiah", "nehemiah"),
    ("Esther", "esther"),
    ("Job", "job"),
    ("Psalms", "psalms"),
    ("Proverbs", "proverbs"),
    ("Ecclesiastes", "ecclesiastes"),
    ("Song of Solomon", "songofsolomon"),
    ("Isaiah", "isaiah"),
    ("Jeremiah", "jeremiah"),
    ("Lamentations", "lamentations"),
    ("Ezekiel", "ezekiel"),
    ("Daniel", "daniel"),
    ("Hosea", "hosea"),
    ("Joel", "joel"),
    ("Amos", "amos"),
    ("Obadiah", "obadiah"),
    ("Jonah", "jonah"),
    ("Micah", "micah"),
    ("Nahum", "nahum"),
    ("Habakkuk", "habakkuk"),
    ("Zephaniah", "zephaniah"),
    ("Haggai", "haggai"),
    ("Zechariah", "zechariah"),
    ("Malachi", "malachi"),
    ("Matthew", "matthew"),
    ("Mark", "mark"),
    ("Luke", "luke"),
    ("John", "john"),
    ("Acts", "acts"),
    ("Romans", "romans"),
    ("1 Corinthians", "1corinthians"),
    ("2 Corinthians", "2corinthians"),
    ("Galatians", "galatians"),
    ("Ephesians", "ephesians"),
    ("Philippians", "philippians"),
    ("Colossians", "colossians"),
    ("1 Thessalonians", "1thessalonians"),
    ("2 Thessalonians", "2thessalonians"),
    ("1 Timothy", "1timothy"),
    ("2 Timothy", "2timothy"),
    ("Titus", "titus"),
    ("Philemon", "philemon"),
    ("Hebrews", "hebrews"),
    ("James", "james"),
    ("1 Peter", "1peter"),
    ("2 Peter", "2peter"),
    ("1 John", "1john"),
    ("2 John", "2john"),
    ("3 John", "3john"),
    ("Jude", "jude"),
    ("Revelation", "revelation"),
]

KJV_URL = "https://raw.githubusercontent.com/jsonbible/jsonbible.github.io/master/kjv.json"
WEB_BOOK_URL = "https://raw.githubusercontent.com/TehShrike/world-english-bible/master/json/{slug}.json"

KJV_NAME_ALIASES = {
    "Song of Songs": "Song of Solomon",
}


def fetch_json(url: str):
    with urllib.request.urlopen(url) as response:
        return json.load(response)


def clean_text(value: str) -> str:
    value = value.replace("\u2019", "'")
    value = re.sub(r"\s+", " ", value)
    value = re.sub(r"\s+([,.;:?!])", r"\1", value)
    return value.strip()


def load_kjv():
    payload = fetch_json(KJV_URL)
    result = {}
    for book in payload["books"]:
        canonical_name = KJV_NAME_ALIASES.get(book["name"], book["name"])
        chapters = {}
        for chapter in book["chapters"]:
            chapter_number = int(chapter["chapter"])
            verses = {}
            for verse in chapter["verses"]:
                verses[int(verse["verse"])] = clean_text(verse["text"])
            chapters[chapter_number] = verses
        result[canonical_name] = chapters
    return result


def load_web_book(slug: str):
    payload = fetch_json(WEB_BOOK_URL.format(slug=slug))
    chapters = {}
    for item in payload:
        chapter_number = item.get("chapterNumber")
        verse_number = item.get("verseNumber")
        value = item.get("value")
        if chapter_number is None or verse_number is None or not value:
            continue

        chapter = chapters.setdefault(int(chapter_number), {})
        chapter.setdefault(int(verse_number), [])
        chapter[int(verse_number)].append(value)

    normalized = {}
    for chapter_number, verses in chapters.items():
        normalized[chapter_number] = {}
        for verse_number, parts in verses.items():
            normalized[chapter_number][verse_number] = clean_text("".join(parts))
    return normalized


def build_dataset():
    kjv = load_kjv()
    books = []

    for index, (name, slug) in enumerate(BOOKS, start=1):
        if name not in kjv:
            raise KeyError(f"Missing KJV book: {name}")

        web = load_web_book(slug)
        book_chapters = []

        for chapter_number in sorted(kjv[name].keys()):
            kjv_verses = kjv[name][chapter_number]
            web_verses = web.get(chapter_number, {})
            verses = []

            for verse_number in sorted(kjv_verses.keys()):
                web_text = web_verses.get(verse_number) or kjv_verses[verse_number]

                verses.append(
                    {
                        "number": verse_number,
                        "kjv": kjv_verses[verse_number],
                        "web": web_text,
                    }
                )

            book_chapters.append(
                {
                    "number": chapter_number,
                    "verses": verses,
                }
            )

        books.append(
            {
                "number": index,
                "id": slug,
                "name": name,
                "chapters": book_chapters,
            }
        )

    return {"books": books}


def main():
    if len(sys.argv) != 2:
        print("usage: generate_bible_dataset.py <output-path>", file=sys.stderr)
        raise SystemExit(1)

    output_path = Path(sys.argv[1])
    output_path.write_text(json.dumps(build_dataset(), ensure_ascii=True, separators=(",", ":")))
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
