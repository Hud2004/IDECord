import SwiftUI

struct IDERowView: View {
    let ide: IDEInfo
    let isRunning: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(ide.imageKey)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 32, height: 32)
                .opacity(ide.isEnabled ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 2) {
                Text(ide.name)
                    .font(.body)
                HStack(spacing: 4) {
                    if isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("실행 중")
                            .foregroundStyle(.green)
                    } else {
                        Text("실행 안 됨")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Toggle("", isOn: Binding(get: { ide.isEnabled }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(isRunning || ide.isEnabled ? 1 : 0.6)
    }
}
