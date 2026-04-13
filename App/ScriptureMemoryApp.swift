import CloudKit
import ScriptureMemory
import SwiftUI
import UserNotifications

@main
struct ScriptureMemoryApp: App {
    @State private var appModel: AppModel
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let progressStore = ReviewProgressStore()
        _appModel = State(initialValue: AppModel(progressStore: progressStore))
        NotificationManager.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appModel.hasCompletedOnboarding {
                    RootView()
                        .onOpenURL { url in
                            appModel.handleIncomingURL(url)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .didTapNotification)) { notification in
                            if let route = notification.userInfo?["route"] as? String,
                               let url = URL(string: "scripturememory://\(route)") {
                                appModel.handleIncomingURL(url)
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: .didAcceptSharedPlan)) { notification in
                            if let planIDString = notification.userInfo?["planID"] as? String,
                               let planID = UUID(uuidString: planIDString),
                               appModel.activePlanEnrollment?.planID != planID {
                                if let plan = BuiltInPlans.plan(withID: planID) ?? appModel.customPlans.first(where: { $0.id == planID }) {
                                    appModel.enrollInPlan(plan)
                                }
                            }
                            appModel.selectedTab = .together
                        }
                        .task {
                            await NotificationManager.clearBadge()
                        }
                } else {
                    OnboardingView()
                }
            }
            .environment(appModel)
        }
    }
}

extension Notification.Name {
    static let didTapNotification = Notification.Name("didTapNotification")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Notification tapped while app was in background/killed
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let route = response.notification.request.content.userInfo["route"] as? String
        let info: [String: Any]? = route.map { ["route": $0] }
        await MainActor.run {
            NotificationCenter.default.post(name: .didTapNotification, object: nil, userInfo: info)
        }
    }

    // Show notification even when app is in foreground
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            let manager = SharedPlanManager.shared
            await manager.acceptShare(cloudKitShareMetadata)
            // Notify the app to navigate to Together tab and auto-enroll
            await manager.fetchGroups()
            if let group = manager.groups.first {
                NotificationCenter.default.post(
                    name: .didAcceptSharedPlan,
                    object: nil,
                    userInfo: ["planID": group.planID.uuidString]
                )
            }
        }
    }
}

extension Notification.Name {
    static let didAcceptSharedPlan = Notification.Name("didAcceptSharedPlan")
}
