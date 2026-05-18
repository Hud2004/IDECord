import SwiftUI

@main
struct IDECordApp: App {
    @State private var service = ActivityService()

    var body: some Scene {
        Window("IDECord", id: "main") {
            ContentView()
                .environment(service)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra {
            MenuBarView()
                .environment(service)
        } label: {
            Image(systemName: service.isRunning ? "hammer.fill" : "hammer")
        }

        Settings {
            SettingsView()
                .environment(service)
        }
    }
}
