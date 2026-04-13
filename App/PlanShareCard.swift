import SwiftUI
import ScriptureMemory

struct PlanShareCard: View {
    let plan: MemorizationPlan
    let currentDay: Int?
    let completedDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: plan.systemImageName)
                    .font(.title2)
                    .foregroundStyle(Color.accentMoss)
                Spacer()
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                    .foregroundStyle(Color.mutedText)
                Text("Hide the Word")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mutedText)
            }

            Text(plan.title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(Color.primaryText)

            Text(plan.description)
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)
                .lineLimit(2)

            HStack(spacing: 16) {
                statBlock(value: "\(plan.duration)", label: "days")
                statBlock(value: "\(plan.totalVerseCount)", label: "verses")
                if completedDays > 0 {
                    statBlock(value: "\(completedDays)", label: "done")
                }
            }

            if completedDays > 0 {
                ProgressView(value: Double(completedDays), total: Double(plan.duration))
                    .tint(Color.accentMoss)
            }

            // Day pills preview
            HStack(spacing: 3) {
                ForEach(plan.days.prefix(20)) { day in
                    let isDone = day.dayNumber <= completedDays
                    let isCurrent = day.dayNumber == currentDay
                    Circle()
                        .fill(isDone ? Color.accentMoss : isCurrent ? Color.accentGold : Color.mutedText.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
                if plan.days.count > 20 {
                    Text("+\(plan.days.count - 20)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.mutedText)
                }
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.borderSand, lineWidth: 1)
        )
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.mutedText)
        }
    }
}

@MainActor
func renderPlanShareImage(plan: MemorizationPlan, currentDay: Int?, completedDays: Int) -> UIImage? {
    let view = PlanShareCard(plan: plan, currentDay: currentDay, completedDays: completedDays)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    return renderer.uiImage
}
