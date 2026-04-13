import UIKit

enum HapticManager {
    static func ratingSubmitted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func recallAdvanced() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func sessionCompleted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func makeItHarder() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func collectionSwitched() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
