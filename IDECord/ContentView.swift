import SwiftUI

struct ContentView: View {
    @Environment(ActivityService.self) var service

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ideList
            Divider()
            footer
        }
        .frame(width: 420, height: 540)
    }

    // MARK: - Sections

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
            Button(service.isRunning ? "중지" : "시작") {
                if service.isRunning { service.stop() } else { service.start() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helpers

    private var statusText: String {
        switch service.connectionStatus {
        case .disconnected:     return "연결 안 됨"
        case .connecting:       return "Discord에 연결 중..."
        case .connected:        return "Discord에 연결됨"
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
