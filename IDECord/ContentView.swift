import SwiftUI

struct ContentView: View {
    @Environment(ActivityService.self) var service
    @AppStorage("appLanguage") private var lang: String = "ko"
    private var en: Bool { lang == "en" }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !service.isAccessibilityGranted {
                accessibilityWarning
            }
            Divider()
            ideList
            Divider()
            footer
        }
        .frame(width: 420, height: 540)
    }

    // MARK: - Sections

    private var accessibilityWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(en ? "Accessibility permission required" : "접근성 권한이 필요합니다")
                    .font(.caption.bold())
                Text(en ? "Grant permission in Settings → Permissions" : "설정 → 권한에서 허용해주세요")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(en ? "Settings" : "설정") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("IDECord")
                    .font(.title2.bold())
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
    }

    private var sortedIDEs: [IDEInfo] {
        service.ides.sorted {
            let aRunning = service.runningBundleIds.contains($0.id)
            let bRunning = service.runningBundleIds.contains($1.id)
            return aRunning && !bRunning
        }
    }

    private var ideList: some View {
        List {
            ForEach(sortedIDEs) { ide in
                IDERowView(
                    ide: ide,
                    isRunning: service.runningBundleIds.contains(ide.id),
                    onToggle: { service.setEnabled($0, for: ide.id) }
                )
            }
        }
        .listStyle(.inset)
        .animation(.default, value: service.runningBundleIds)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let label = service.currentActivityLabel {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(service.isRunning ? (en ? "Stop" : "중지") : (en ? "Start" : "시작")) {
                if service.isRunning { service.stop() } else { service.start() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helpers

    private var statusText: String {
        switch service.connectionStatus {
        case .disconnected:     return en ? "Not Connected" : "연결 안 됨"
        case .connecting:       return en ? "Connecting to Discord..." : "Discord에 연결 중..."
        case .connected:        return en ? "Connected to Discord" : "Discord에 연결됨"
        case .error(let msg):   return msg
        }
    }

    private var statusColor: Color {
        switch service.connectionStatus {
        case .connected:    return .green
        case .connecting:   return .orange
        case .error:        return .red
        case .disconnected: return .gray
        }
    }
}

#Preview {
    ContentView()
        .environment(ActivityService())
}
