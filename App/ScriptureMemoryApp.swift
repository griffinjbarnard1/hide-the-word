import CloudKit
import ScriptureMemory
import SwiftUI
import UserNotifications

@main
struct ScriptureMemoryApp: App {
    @State private var appModel: AppModel?
    @State private var blockingInitializationError: String?
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let persistenceResult = ReviewProgressStore.initialize()
        let catalogError = BibleCatalog.initializationError

        let initialError: String?
        let initialModel: AppModel?
        if let persistenceError = persistenceResult.error {
            initialError = persistenceError.localizedDescription
            initialModel = nil
        } else if let catalogError {
            initialError = catalogError.localizedDescription
            initialModel = nil
        } else {
            initialError = nil
            initialModel = AppModel(progressStore: persistenceResult.store)
        }

        _blockingInitializationError = State(initialValue: initialError)
        _appModel = State(initialValue: initialModel)
        NotificationManager.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let blockingInitializationError {
                    InitializationErrorView(message: blockingInitializationError)
                } else if let appModel {
                    Group {
                        if appModel.hasCompletedOnboarding {
                            RootView()
                                .onOpenURL { url in
                                    appModel.handleIncomingURL(url)
                                }
                                .onReceive(NotificationCenter.default.publisher(for: .didTapNotification)) { notification in
                                    if let route = notification.userInfo?["route"] as? String,
                                       route == "session/today" {
                                        appModel.startOrResumeSession()
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
                } else {
                    InitializationErrorView(message: "App failed to initialize. Please relaunch.")
                }
            }
        }
    }
}

private struct InitializationErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Unable to Start Scripture Memory")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("A required local resource failed to load.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Text("Please reinstall the app or contact support if this persists.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
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
