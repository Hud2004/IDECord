import SwiftUI
import AppKit

@main
struct IDECordApp: App {
    @State private var service = ActivityService()

    init() {
        // Prevent SIGPIPE from crashing the app when writing to a closed Discord socket
        signal(SIGPIPE, SIG_IGN)
        // Terminate any existing instances so this new launch always takes over
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let myPid = ProcessInfo.processInfo.processIdentifier
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != myPid }
            .forEach { $0.terminate() }
    }

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
