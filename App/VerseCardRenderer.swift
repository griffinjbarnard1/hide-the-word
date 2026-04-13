import SwiftUI

struct VerseShareCard: View {
    let reference: String
    let text: String
    let translation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(text)
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))

            HStack {
                Text("— \(reference)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))

                Spacer()

                Text(translation)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(red: 0.99, green: 0.98, blue: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

@MainActor
func renderVerseImage(reference: String, text: String, translation: String) -> UIImage? {
    let renderer = ImageRenderer(content: VerseShareCard(reference: reference, text: text, translation: translation))
    renderer.scale = 3
    return renderer.uiImage
}
