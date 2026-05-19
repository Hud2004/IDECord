import SwiftUI

struct MenuBarView: View {
    @Environment(ActivityService.self) var service
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appLanguage") private var lang: String = "ko"
    private var en: Bool { lang == "en" }

    var body: some View {
        Group {
            if let label = service.currentActivityLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
            }

            Button(en ? "Menu" : "메뉴") {
                // Prefer AppKit window lookup (more reliable from MenuBarExtra)
                if let w = NSApp.windows.first(where: { !($0 is NSPanel) && $0.title == "IDECord" }) {
                    w.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "main")
                }
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(service.isRunning ? (en ? "Stop Monitoring" : "모니터링 중지") : (en ? "Start Monitoring" : "모니터링 시작")) {
                if service.isRunning { service.stop() } else { service.start() }
            }

            Button(en ? "Settings..." : "설정...") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button(en ? "Quit IDECord" : "IDECord 종료") {
                NSApp.terminate(nil)
            }
        }
    }
}
