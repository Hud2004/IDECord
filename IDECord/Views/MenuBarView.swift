import SwiftUI

struct MenuBarView: View {
    @Environment(ActivityService.self) var service

    var body: some View {
        Group {
            if let label = service.currentActivityLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
            }

            Button(service.isRunning ? "모니터링 중지" : "모니터링 시작") {
                if service.isRunning { service.stop() } else { service.start() }
            }

            Button("설정...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("IDECord 종료") {
                NSApp.terminate(nil)
            }
        }
    }
}
