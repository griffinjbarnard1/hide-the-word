import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let headline: String
    let bodyText: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentMoss)

            Text(headline)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)

            if let ctaTitle, let ctaAction {
                Button(ctaTitle, action: ctaAction)
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
        }
        .cardSurface()
    }
}
