import SwiftUI
import ScriptureMemory

struct WeeklyProgressData {
    let reviewCount: Int
    let newVersesStarted: Int
    let streak: Int
    let masteryChanges: Int
    let collectionName: String
    let tierCounts: [MasteryTier: Int]
}

struct WeeklyProgressShareCard: View {
    let data: WeeklyProgressData

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Hide the Word")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.37, green: 0.42, blue: 0.32))
                Spacer()
                Text("Weekly Summary")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
            }

            VStack(alignment: .leading, spacing: 6) {
                if data.streak > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color(red: 0.74, green: 0.62, blue: 0.35))
                        Text("\(data.streak)-day streak")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))
                    }
                }

                Text("\(data.reviewCount) reviews this week")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))

                if data.newVersesStarted > 0 {
                    Text("\(data.newVersesStarted) new verse\(data.newVersesStarted == 1 ? "" : "s") started")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
                }
            }

            HStack(spacing: 16) {
                ForEach(MasteryTier.allCases, id: \.self) { tier in
                    let count = data.tierCounts[tier, default: 0]
                    VStack(spacing: 2) {
                        Text("\(count)")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.09))
                        Text(tier.title)
                            .font(.caption2)
                            .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(12)
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(data.collectionName)
                .font(.caption)
                .foregroundStyle(Color(red: 0.54, green: 0.51, blue: 0.47))
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(red: 0.99, green: 0.98, blue: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

@MainActor
func renderWeeklyProgressImage(data: WeeklyProgressData) -> UIImage? {
    let renderer = ImageRenderer(content: WeeklyProgressShareCard(data: data))
    renderer.scale = 3
    return renderer.uiImage
}
