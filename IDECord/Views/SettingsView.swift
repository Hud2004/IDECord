import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var lang: String = "ko"
    private var en: Bool { lang == "en" }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $lang) {
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text(en ? "Language" : "언어")
            }

            Section {
                Text(en ? "Accessibility permission is required to read window titles."
                        : "창 제목 읽기(Accessibility) 권한이 필요합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(en ? "Open Accessibility Settings" : "손쉬운 사용 설정 열기") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            } header: {
                Text(en ? "Permissions" : "권한")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
    }
}
