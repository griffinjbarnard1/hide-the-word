import SwiftUI
import ScriptureMemory

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView(selection: Binding(
            get: { appModel.selectedTab },
            set: { appModel.selectedTab = $0 }
        )) {
            NavigationStack {
                HomeView()
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(AppShellTab.home)
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                JourneyView()
                    .navigationTitle("Journey")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(AppShellTab.journey)
            .tabItem {
                Label("Journey", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            NavigationStack {
                TogetherView()
                    .navigationTitle("Together")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(AppShellTab.together)
            .tabItem {
                Label("Together", systemImage: "person.2")
            }


            NavigationStack {
                VerseLibraryView()
                    .navigationTitle("Library")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tag(AppShellTab.library)
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
        }
        .background(Color.screenBackground)
        .animation(.snappy(duration: 0.28), value: appModel.selectedTab)
        .sheet(item: overlayRouteBinding) { route in
            NavigationStack {
                switch route {
                case .settings:
                    SettingsView()
                case .plans:
                    PlanLibraryView()
                default:
                    EmptyView()
                }
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: todaySessionBinding) {
            SessionFlowView()
        }
        .tint(Color.accentMoss)
        .preferredColorScheme(appModel.appearance == .system ? nil : appModel.appearance == .dark ? .dark : .light)
    }

    private var overlayRouteBinding: Binding<AppRoute?> {
        Binding(
            get: {
                switch appModel.activeRoute {
                case .settings, .plans:
                    return appModel.activeRoute
                default:
                    return nil
                }
            },
            set: { newValue in
                if newValue == nil {
                    appModel.dismissActiveRoute()
                }
            }
        )
    }

    private var todaySessionBinding: Binding<Bool> {
        Binding(
            get: { appModel.activeRoute == .todaySession },
            set: { isPresented in
                if !isPresented, appModel.activeRoute == .todaySession {
                    appModel.dismissActiveRoute()
                }
            }
        )
    }
}

#Preview {
    RootView()
        .environment(AppModel(progressStore: ReviewProgressStore(inMemory: true)))
}
