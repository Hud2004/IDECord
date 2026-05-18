import SwiftUI

struct SettingsView: View {
    @Environment(ActivityService.self) var service
    @State private var globalIdDraft = ""
    @State private var ideIdDrafts: [String: String] = [:]
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                clientIdRow(label: "기본 Client ID", placeholder: "IDECord 앱 ID (폴백용)",
                            value: $globalIdDraft)

                Text("IDE별 Client ID가 없을 때 사용됩니다. discord.com/developers 에서 애플리케이션을 만들고 Rich Presence를 활성화하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Discord 연동")
            }

            Section {
                ForEach(service.ides) { ide in
                    clientIdRow(
                        label: ide.name,
                        placeholder: "없으면 기본 ID 사용",
                        value: Binding(
                            get: { ideIdDrafts[ide.id] ?? "" },
                            set: { ideIdDrafts[ide.id] = $0 }
                        ),
                        icon: ide.sfSymbol
                    )
                }

                Text("IDE마다 별도의 Discord 앱을 만들면 \"Xcode 플레이 중\", \"VS Code 플레이 중\" 처럼 IDE 이름으로 표시됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("IDE별 Client ID (선택)")
            }

            Section {
                HStack {
                    Spacer()
                    if saved {
                        Label("저장됨", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .transition(.opacity)
                    }
                    Button("저장") { saveAll() }
                        .buttonStyle(.borderedProminent)
                }
            }

            Section {
                Text("창 제목 읽기(Accessibility) 권한이 필요합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("손쉬운 사용 설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            } header: {
                Text("권한")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear { loadDrafts() }
    }

    @ViewBuilder
    private func clientIdRow(label: String, placeholder: String, value: Binding<String>, icon: String? = nil) -> some View {
        LabeledContent {
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                .font(.system(.body, design: .monospaced))
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                }
                Text(label)
            }
        }
    }

    private func loadDrafts() {
        globalIdDraft = service.clientId
        for ide in service.ides {
            ideIdDrafts[ide.id] = UserDefaults.standard.string(forKey: "clientId_\(ide.id)") ?? ""
        }
    }

    private func saveAll() {
        service.clientId = globalIdDraft
        for ide in service.ides {
            service.setIdeClientId(ideIdDrafts[ide.id] ?? "", for: ide.id)
        }
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }
}
