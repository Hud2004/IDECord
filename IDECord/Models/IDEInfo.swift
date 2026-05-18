import Foundation

struct IDEInfo: Identifiable {
    let id: String
    let name: String
    let sfSymbol: String
    let style: TitleStyle
    let imageKey: String      // Discord Art Assets 업로드 시 사용할 키 이름
    let defaultClientId: String?
    var isEnabled: Bool

    enum TitleStyle {
        case xcode      // "file.swift — ProjectName"
        case vsCode     // "● file.ts — folder — Visual Studio Code"
        case jetbrains  // "file.kt – ProjectName – IDE" (신 UI: "ProjectName" 만)
        case generic
    }

    static let defaults: [IDEInfo] = [
        IDEInfo(id: "com.apple.dt.Xcode",              name: "Xcode",               sfSymbol: "hammer.fill",              style: .xcode,     imageKey: "xcode",         defaultClientId: "1505864787068846190", isEnabled: false),
        IDEInfo(id: "com.microsoft.VSCode",             name: "Visual Studio Code",  sfSymbol: "curlybraces",              style: .vsCode,    imageKey: "vscode",        defaultClientId: "1505864921273991358", isEnabled: false),
        IDEInfo(id: "com.todesktop.230313mzl4w4u92",   name: "Cursor",              sfSymbol: "curlybraces.square.fill",  style: .vsCode,    imageKey: "cursor",        defaultClientId: "1505864997220253876", isEnabled: false),
        IDEInfo(id: "com.jetbrains.intellij",           name: "IntelliJ IDEA",       sfSymbol: "j.square.fill",            style: .jetbrains, imageKey: "intellij",      defaultClientId: "1505865091856207912", isEnabled: false),
        IDEInfo(id: "com.jetbrains.webstorm",           name: "WebStorm",            sfSymbol: "globe",                    style: .jetbrains, imageKey: "webstorm",      defaultClientId: "1505865168100524052", isEnabled: false),
        IDEInfo(id: "com.jetbrains.pycharm",            name: "PyCharm",             sfSymbol: "p.square.fill",            style: .jetbrains, imageKey: "pycharm",       defaultClientId: "1505865241874137098", isEnabled: false),
        IDEInfo(id: "com.google.android.studio",        name: "Android Studio",      sfSymbol: "a.square.fill",            style: .jetbrains, imageKey: "androidstudio", defaultClientId: "1505865317564547072", isEnabled: false),
        IDEInfo(id: "com.jetbrains.clion",              name: "CLion",               sfSymbol: "c.square.fill",            style: .jetbrains, imageKey: "clion",         defaultClientId: "1505865407125524581", isEnabled: false),
        IDEInfo(id: "com.jetbrains.goland",             name: "GoLand",              sfSymbol: "g.square.fill",            style: .jetbrains, imageKey: "goland",        defaultClientId: "1505865466910871553", isEnabled: false),
        IDEInfo(id: "com.jetbrains.rider",              name: "Rider",               sfSymbol: "r.square.fill",            style: .jetbrains, imageKey: "rider",         defaultClientId: "1505865526033776720", isEnabled: false),
        IDEInfo(id: "com.panic.Nova",                   name: "Nova",                sfSymbol: "n.square.fill",            style: .vsCode,    imageKey: "nova",          defaultClientId: "1505876666314915901", isEnabled: false),
        IDEInfo(id: "com.google.antigravity",           name: "Antigravity",         sfSymbol: "wand.and.stars",           style: .vsCode,    imageKey: "antigravity",   defaultClientId: "1505876756261896313", isEnabled: false),
    ]
}
