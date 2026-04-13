import Foundation

public enum BuiltInPlans {
    public static let allPlans: [MemorizationPlan] = [
        psalm23,
        psalm1,
        psalm91,
        lordsPrayer,
        loveChapter,
        beatitudes,
        armorOfGod,
        romans8,
        faithFoundations,
        anxietyAndPeace,
        gospelEssentials,
        godsPromises,
        fruitOfTheSpirit,
        greatCommission,
        proverbsWisdom,
    ]

    // MARK: - Book Studies

    public static let psalm23 = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000001")!,
        title: "Psalm 23 in 7 Days",
        description: "The Shepherd's Psalm, one verse per day. A gentle first plan.",
        systemImageName: "leaf",
        category: .book,
        days: (1...6).map { day in
            PlanDay(
                dayNumber: day,
                title: "Psalm 23:\(day)",
                verseReferences: [VerseReference(bookID: "psalms", chapter: 23, verse: day)],
                goal: .learnNew
            )
        } + [
            PlanDay(dayNumber: 7, title: "Full Psalm recall", verseReferences: (1...6).map { VerseReference(bookID: "psalms", chapter: 23, verse: $0) }, goal: .fullRecall)
        ],
        isBuiltIn: true
    )

    public static let psalm1 = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000002")!,
        title: "Psalm 1 in 5 Days",
        description: "The blessed life. Short and foundational.",
        systemImageName: "tree",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Psalm 1:1", verseReferences: [VerseReference(bookID: "psalms", chapter: 1, verse: 1)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Psalm 1:2", verseReferences: [VerseReference(bookID: "psalms", chapter: 1, verse: 2)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Psalm 1:3", verseReferences: [VerseReference(bookID: "psalms", chapter: 1, verse: 3)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Psalm 1:4-5", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 1, verse: 4),
                VerseReference(bookID: "psalms", chapter: 1, verse: 5),
            ], goal: .learnNew),
            PlanDay(dayNumber: 5, title: "Psalm 1:6 + full recall", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 1, verse: 6),
            ], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    // MARK: - Thematic Plans

    public static let faithFoundations = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000003")!,
        title: "Faith Foundations",
        description: "7 core verses on trust, dependence, and confidence in God.",
        systemImageName: "shield.lefthalf.filled",
        category: .thematic,
        days: [
            PlanDay(dayNumber: 1, title: "Hebrews 11:1", verseReferences: [VerseReference(bookID: "hebrews", chapter: 11, verse: 1)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Proverbs 3:5", verseReferences: [VerseReference(bookID: "proverbs", chapter: 3, verse: 5)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Proverbs 3:6", verseReferences: [VerseReference(bookID: "proverbs", chapter: 3, verse: 6)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Romans 10:17", verseReferences: [VerseReference(bookID: "romans", chapter: 10, verse: 17)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "2 Corinthians 5:7", verseReferences: [VerseReference(bookID: "2corinthians", chapter: 5, verse: 7)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Mark 11:24", verseReferences: [VerseReference(bookID: "mark", chapter: 11, verse: 24)], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    public static let anxietyAndPeace = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000004")!,
        title: "Anxiety & Peace",
        description: "10 days of verses for prayer, peace, and steadiness under pressure.",
        systemImageName: "wind",
        category: .thematic,
        days: [
            PlanDay(dayNumber: 1, title: "Philippians 4:6", verseReferences: [VerseReference(bookID: "philippians", chapter: 4, verse: 6)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Philippians 4:7", verseReferences: [VerseReference(bookID: "philippians", chapter: 4, verse: 7)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "1 Peter 5:7", verseReferences: [VerseReference(bookID: "1peter", chapter: 5, verse: 7)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Isaiah 41:10", verseReferences: [VerseReference(bookID: "isaiah", chapter: 41, verse: 10)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Matthew 6:34", verseReferences: [VerseReference(bookID: "matthew", chapter: 6, verse: 34)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Psalm 46:1", verseReferences: [VerseReference(bookID: "psalms", chapter: 46, verse: 1)], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "John 14:27", verseReferences: [VerseReference(bookID: "john", chapter: 14, verse: 27)], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Psalm 55:22", verseReferences: [VerseReference(bookID: "psalms", chapter: 55, verse: 22)], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    public static let gospelEssentials = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000005")!,
        title: "The Gospel in Verses",
        description: "10 days through the core message of salvation.",
        systemImageName: "cross.case",
        category: .thematic,
        days: [
            PlanDay(dayNumber: 1, title: "Romans 3:23", verseReferences: [VerseReference(bookID: "romans", chapter: 3, verse: 23)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Romans 6:23", verseReferences: [VerseReference(bookID: "romans", chapter: 6, verse: 23)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "John 3:16", verseReferences: [VerseReference(bookID: "john", chapter: 3, verse: 16)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Ephesians 2:8", verseReferences: [VerseReference(bookID: "ephesians", chapter: 2, verse: 8)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Ephesians 2:9", verseReferences: [VerseReference(bookID: "ephesians", chapter: 2, verse: 9)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Romans 5:8", verseReferences: [VerseReference(bookID: "romans", chapter: 5, verse: 8)], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "2 Corinthians 5:17", verseReferences: [VerseReference(bookID: "2corinthians", chapter: 5, verse: 17)], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Romans 10:9", verseReferences: [VerseReference(bookID: "romans", chapter: 10, verse: 9)], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    public static let armorOfGod = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000006")!,
        title: "Armor of God",
        description: "Ephesians 6:10-18 in 7 days. Put on the full armor.",
        systemImageName: "shield.checkered",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Eph 6:10-11", verseReferences: [
                VerseReference(bookID: "ephesians", chapter: 6, verse: 10),
                VerseReference(bookID: "ephesians", chapter: 6, verse: 11),
            ], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Eph 6:12", verseReferences: [VerseReference(bookID: "ephesians", chapter: 6, verse: 12)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Eph 6:13-14", verseReferences: [
                VerseReference(bookID: "ephesians", chapter: 6, verse: 13),
                VerseReference(bookID: "ephesians", chapter: 6, verse: 14),
            ], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Eph 6:15-16", verseReferences: [
                VerseReference(bookID: "ephesians", chapter: 6, verse: 15),
                VerseReference(bookID: "ephesians", chapter: 6, verse: 16),
            ], goal: .learnNew),
            PlanDay(dayNumber: 5, title: "Eph 6:17", verseReferences: [VerseReference(bookID: "ephesians", chapter: 6, verse: 17)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Eph 6:18", verseReferences: [VerseReference(bookID: "ephesians", chapter: 6, verse: 18)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Full passage recall", verseReferences: (10...18).map { VerseReference(bookID: "ephesians", chapter: 6, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let godsPromises = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000007")!,
        title: "God's Promises",
        description: "14 days of promises from across Scripture. Strength for every season.",
        systemImageName: "hands.sparkles",
        category: .thematic,
        days: [
            PlanDay(dayNumber: 1, title: "Jeremiah 29:11", verseReferences: [VerseReference(bookID: "jeremiah", chapter: 29, verse: 11)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Isaiah 40:31", verseReferences: [VerseReference(bookID: "isaiah", chapter: 40, verse: 31)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Romans 8:28", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 28)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Psalm 23:4", verseReferences: [VerseReference(bookID: "psalms", chapter: 23, verse: 4)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Matthew 11:28", verseReferences: [VerseReference(bookID: "matthew", chapter: 11, verse: 28)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Joshua 1:9", verseReferences: [VerseReference(bookID: "joshua", chapter: 1, verse: 9)], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "Psalm 34:18", verseReferences: [VerseReference(bookID: "psalms", chapter: 34, verse: 18)], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Isaiah 43:2", verseReferences: [VerseReference(bookID: "isaiah", chapter: 43, verse: 2)], goal: .learnNew),
            PlanDay(dayNumber: 11, title: "Deuteronomy 31:6", verseReferences: [VerseReference(bookID: "deuteronomy", chapter: 31, verse: 6)], goal: .learnNew),
            PlanDay(dayNumber: 12, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 13, title: "Philippians 4:19", verseReferences: [VerseReference(bookID: "philippians", chapter: 4, verse: 19)], goal: .learnNew),
            PlanDay(dayNumber: 14, title: "Lamentations 3:22-23", verseReferences: [
                VerseReference(bookID: "lamentations", chapter: 3, verse: 22),
                VerseReference(bookID: "lamentations", chapter: 3, verse: 23),
            ], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    public static let lordsPrayer = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000008")!,
        title: "The Lord's Prayer",
        description: "Matthew 6:9-13 in 5 days. The prayer Jesus taught.",
        systemImageName: "hands.and.sparkles",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Matt 6:9", verseReferences: [VerseReference(bookID: "matthew", chapter: 6, verse: 9)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Matt 6:10", verseReferences: [VerseReference(bookID: "matthew", chapter: 6, verse: 10)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Matt 6:11-12", verseReferences: [
                VerseReference(bookID: "matthew", chapter: 6, verse: 11),
                VerseReference(bookID: "matthew", chapter: 6, verse: 12),
            ], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Matt 6:13", verseReferences: [VerseReference(bookID: "matthew", chapter: 6, verse: 13)], goal: .learnNew),
            PlanDay(dayNumber: 5, title: "Full prayer recall", verseReferences: (9...13).map { VerseReference(bookID: "matthew", chapter: 6, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let loveChapter = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-000000000009")!,
        title: "The Love Chapter",
        description: "1 Corinthians 13:1-8 in 7 days. What love really is.",
        systemImageName: "heart",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "1 Cor 13:1", verseReferences: [VerseReference(bookID: "1corinthians", chapter: 13, verse: 1)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "1 Cor 13:2-3", verseReferences: [
                VerseReference(bookID: "1corinthians", chapter: 13, verse: 2),
                VerseReference(bookID: "1corinthians", chapter: 13, verse: 3),
            ], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "1 Cor 13:4", verseReferences: [VerseReference(bookID: "1corinthians", chapter: 13, verse: 4)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "1 Cor 13:5", verseReferences: [VerseReference(bookID: "1corinthians", chapter: 13, verse: 5)], goal: .learnNew),
            PlanDay(dayNumber: 5, title: "1 Cor 13:6-7", verseReferences: [
                VerseReference(bookID: "1corinthians", chapter: 13, verse: 6),
                VerseReference(bookID: "1corinthians", chapter: 13, verse: 7),
            ], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "1 Cor 13:8", verseReferences: [VerseReference(bookID: "1corinthians", chapter: 13, verse: 8)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Full passage recall", verseReferences: (1...8).map { VerseReference(bookID: "1corinthians", chapter: 13, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let beatitudes = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-00000000000A")!,
        title: "The Beatitudes",
        description: "Matthew 5:3-12 in 10 days. The upside-down kingdom.",
        systemImageName: "mountain.2",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Matt 5:3", verseReferences: [VerseReference(bookID: "matthew", chapter: 5, verse: 3)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Matt 5:4", verseReferences: [VerseReference(bookID: "matthew", chapter: 5, verse: 4)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Matt 5:5-6", verseReferences: [
                VerseReference(bookID: "matthew", chapter: 5, verse: 5),
                VerseReference(bookID: "matthew", chapter: 5, verse: 6),
            ], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Matt 5:7-8", verseReferences: [
                VerseReference(bookID: "matthew", chapter: 5, verse: 7),
                VerseReference(bookID: "matthew", chapter: 5, verse: 8),
            ], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Matt 5:9", verseReferences: [VerseReference(bookID: "matthew", chapter: 5, verse: 9)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Matt 5:10", verseReferences: [VerseReference(bookID: "matthew", chapter: 5, verse: 10)], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "Matt 5:11-12", verseReferences: [
                VerseReference(bookID: "matthew", chapter: 5, verse: 11),
                VerseReference(bookID: "matthew", chapter: 5, verse: 12),
            ], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Full Beatitudes recall", verseReferences: (3...12).map { VerseReference(bookID: "matthew", chapter: 5, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let psalm91 = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-00000000000B")!,
        title: "Psalm 91",
        description: "The psalm of protection and refuge. 16 verses over 10 days.",
        systemImageName: "shield",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Psalm 91:1-2", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 1),
                VerseReference(bookID: "psalms", chapter: 91, verse: 2),
            ], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Psalm 91:3-4", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 3),
                VerseReference(bookID: "psalms", chapter: 91, verse: 4),
            ], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Psalm 91:5-6", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 5),
                VerseReference(bookID: "psalms", chapter: 91, verse: 6),
            ], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Psalm 91:7-8", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 7),
                VerseReference(bookID: "psalms", chapter: 91, verse: 8),
            ], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Psalm 91:9-10", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 9),
                VerseReference(bookID: "psalms", chapter: 91, verse: 10),
            ], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Psalm 91:11-12", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 11),
                VerseReference(bookID: "psalms", chapter: 91, verse: 12),
            ], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "Psalm 91:13-16", verseReferences: [
                VerseReference(bookID: "psalms", chapter: 91, verse: 13),
                VerseReference(bookID: "psalms", chapter: 91, verse: 14),
                VerseReference(bookID: "psalms", chapter: 91, verse: 15),
                VerseReference(bookID: "psalms", chapter: 91, verse: 16),
            ], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Full psalm recall", verseReferences: (1...16).map { VerseReference(bookID: "psalms", chapter: 91, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let romans8 = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-00000000000C")!,
        title: "Romans 8 Highlights",
        description: "Key verses from the greatest chapter in the Bible. 10 days.",
        systemImageName: "text.book.closed",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Romans 8:1", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 1)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Romans 8:5-6", verseReferences: [
                VerseReference(bookID: "romans", chapter: 8, verse: 5),
                VerseReference(bookID: "romans", chapter: 8, verse: 6),
            ], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Romans 8:11", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 11)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Romans 8:18", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 18)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Romans 8:26", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 26)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Romans 8:28", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 28)], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "Romans 8:31", verseReferences: [VerseReference(bookID: "romans", chapter: 8, verse: 31)], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Romans 8:37-39", verseReferences: [
                VerseReference(bookID: "romans", chapter: 8, verse: 37),
                VerseReference(bookID: "romans", chapter: 8, verse: 38),
                VerseReference(bookID: "romans", chapter: 8, verse: 39),
            ], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    public static let fruitOfTheSpirit = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-00000000000D")!,
        title: "Fruit of the Spirit",
        description: "Galatians 5:22-26 in 5 days. The character of a Spirit-led life.",
        systemImageName: "leaf.circle",
        category: .thematic,
        days: [
            PlanDay(dayNumber: 1, title: "Galatians 5:22", verseReferences: [VerseReference(bookID: "galatians", chapter: 5, verse: 22)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Galatians 5:23", verseReferences: [VerseReference(bookID: "galatians", chapter: 5, verse: 23)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Galatians 5:24-25", verseReferences: [
                VerseReference(bookID: "galatians", chapter: 5, verse: 24),
                VerseReference(bookID: "galatians", chapter: 5, verse: 25),
            ], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Galatians 5:26", verseReferences: [VerseReference(bookID: "galatians", chapter: 5, verse: 26)], goal: .learnNew),
            PlanDay(dayNumber: 5, title: "Full passage recall", verseReferences: (22...26).map { VerseReference(bookID: "galatians", chapter: 5, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let greatCommission = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-00000000000E")!,
        title: "The Great Commission",
        description: "Matthew 28:18-20. Three verses, three days, one mission.",
        systemImageName: "globe.americas",
        category: .book,
        days: [
            PlanDay(dayNumber: 1, title: "Matthew 28:18", verseReferences: [VerseReference(bookID: "matthew", chapter: 28, verse: 18)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Matthew 28:19", verseReferences: [VerseReference(bookID: "matthew", chapter: 28, verse: 19)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Matthew 28:20", verseReferences: [VerseReference(bookID: "matthew", chapter: 28, verse: 20)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Full recall", verseReferences: (18...20).map { VerseReference(bookID: "matthew", chapter: 28, verse: $0) }, goal: .fullRecall),
        ],
        isBuiltIn: true
    )

    public static let proverbsWisdom = MemorizationPlan(
        id: UUID(uuidString: "B1000001-0000-0000-0000-00000000000F")!,
        title: "Proverbs for Daily Life",
        description: "14 days of wisdom for decisions, speech, and character.",
        systemImageName: "lightbulb",
        category: .thematic,
        days: [
            PlanDay(dayNumber: 1, title: "Proverbs 3:5", verseReferences: [VerseReference(bookID: "proverbs", chapter: 3, verse: 5)], goal: .learnNew),
            PlanDay(dayNumber: 2, title: "Proverbs 3:6", verseReferences: [VerseReference(bookID: "proverbs", chapter: 3, verse: 6)], goal: .learnNew),
            PlanDay(dayNumber: 3, title: "Proverbs 4:23", verseReferences: [VerseReference(bookID: "proverbs", chapter: 4, verse: 23)], goal: .learnNew),
            PlanDay(dayNumber: 4, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 5, title: "Proverbs 16:3", verseReferences: [VerseReference(bookID: "proverbs", chapter: 16, verse: 3)], goal: .learnNew),
            PlanDay(dayNumber: 6, title: "Proverbs 16:9", verseReferences: [VerseReference(bookID: "proverbs", chapter: 16, verse: 9)], goal: .learnNew),
            PlanDay(dayNumber: 7, title: "Proverbs 18:21", verseReferences: [VerseReference(bookID: "proverbs", chapter: 18, verse: 21)], goal: .learnNew),
            PlanDay(dayNumber: 8, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 9, title: "Proverbs 22:6", verseReferences: [VerseReference(bookID: "proverbs", chapter: 22, verse: 6)], goal: .learnNew),
            PlanDay(dayNumber: 10, title: "Proverbs 27:17", verseReferences: [VerseReference(bookID: "proverbs", chapter: 27, verse: 17)], goal: .learnNew),
            PlanDay(dayNumber: 11, title: "Proverbs 15:1", verseReferences: [VerseReference(bookID: "proverbs", chapter: 15, verse: 1)], goal: .learnNew),
            PlanDay(dayNumber: 12, title: "Review day", verseReferences: [], goal: .reviewOnly),
            PlanDay(dayNumber: 13, title: "Proverbs 11:2", verseReferences: [VerseReference(bookID: "proverbs", chapter: 11, verse: 2)], goal: .learnNew),
            PlanDay(dayNumber: 14, title: "Proverbs 3:7-8", verseReferences: [
                VerseReference(bookID: "proverbs", chapter: 3, verse: 7),
                VerseReference(bookID: "proverbs", chapter: 3, verse: 8),
            ], goal: .learnNew),
        ],
        isBuiltIn: true
    )

    public static func plan(withID id: UUID) -> MemorizationPlan? {
        allPlans.first { $0.id == id }
    }
}
