import AppKit
import ApplicationServices

final class IDEMonitor {

    struct Activity {
        let details: String
        let state: String?
        let ideName: String
        let largeImage: String
    }

    struct Status {
        let bundleId: String
        let isRunning: Bool
        let activity: Activity?
    }

    func check(_ ide: IDEInfo) -> Status {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == ide.id }) else {
            return Status(bundleId: ide.id, isRunning: false, activity: nil)
        }
        let pid = app.processIdentifier
        let title = windowTitle(pid: pid)
        let activity = parse(title: title, pid: pid, ide: ide)
        return Status(bundleId: ide.id, isRunning: true, activity: activity)
    }

    // MARK: - Accessibility

    private func frontWindow(pid: pid_t) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(pid)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
              let windows = ref as? [AXUIElement] else { return nil }
        return windows.first
    }

    private func windowTitle(pid: pid_t) -> String? {
        guard let window = frontWindow(pid: pid) else { return nil }
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &ref) == .success,
              let title = ref as? String, !title.isEmpty else { return nil }
        return title
    }

    /// JetBrains 신 UI: 창 제목에 파일명이 없을 때 AXDocument 또는 포커스 요소로 파일명 보완
    private func jetbrainsActiveFile(pid: pid_t) -> String? {
        guard let window = frontWindow(pid: pid) else { return nil }

        // 1. AXDocument 속성 (일부 버전에서 현재 파일 경로 제공)
        var docRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXDocument" as CFString, &docRef) == .success,
           let docPath = docRef as? String, !docPath.isEmpty {
            return URL(string: docPath)?.lastPathComponent
                ?? URL(fileURLWithPath: docPath).lastPathComponent
        }

        // 2. 포커스된 UI 요소에서 제목 추출
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else { return nil }
        let focusedElem = focused as! AXUIElement

        // 포커스 요소부터 위로 올라가며 파일명처럼 보이는 제목 탐색
        var current: AXUIElement = focusedElem
        for _ in 0..<8 {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = titleRef as? String, t.contains("."), !t.contains(" ") {
                return t
            }
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef else { break }
            current = parent as! AXUIElement
        }
        return nil
    }

    // MARK: - Parsing

    private func parse(title: String?, pid: pid_t, ide: IDEInfo) -> Activity {
        let key = ide.imageKey

        guard let title, !title.isEmpty else {
            return Activity(details: "Coding", state: nil, ideName: ide.name, largeImage: key)
        }

        switch ide.style {
        case .xcode:
            // "filename.swift — ProjectName — Xcode" 또는 "filename.swift — ProjectName"
            let parts = title.components(separatedBy: " \u{2014} ").filter { $0 != "Xcode" }
            if parts.count >= 2 {
                return Activity(details: "Editing \(parts[0])", state: "In \(parts[1])", ideName: ide.name, largeImage: key)
            } else if parts.count == 1 {
                return Activity(details: "Coding", state: "In \(parts[0])", ideName: ide.name, largeImage: key)
            }

        case .vsCode:
            // "● filename.ts — folder — Visual Studio Code"
            let appSuffix = [" — Visual Studio Code", " — Cursor", " — Nova", " — Antigravity"]
            var clean = title.hasPrefix("\u{25CF} ") ? String(title.dropFirst(2)) : title
            for suffix in appSuffix { clean = clean.replacingOccurrences(of: suffix, with: "") }
            let parts = clean.components(separatedBy: " \u{2014} ")
            if parts.count >= 2 {
                return Activity(details: "Editing \(parts[0])", state: "In \(parts[parts.count - 1])", ideName: ide.name, largeImage: key)
            } else if parts.count == 1, !parts[0].isEmpty {
                return Activity(details: "Coding", state: "In \(parts[0])", ideName: ide.name, largeImage: key)
            }

        case .jetbrains:
            // 구 UI: "file.kt – ProjectName – IDE Name" (en dash)
            let parts = title.components(separatedBy: " \u{2013} ").filter { $0 != ide.name }
            if parts.count >= 2 {
                return Activity(details: "Editing \(parts[0])", state: "In \(parts[1])", ideName: ide.name, largeImage: key)
            }
            // 신 UI: 창 제목이 프로젝트명만 있을 때 → AX로 파일명 보완
            if parts.count == 1 {
                let project = parts[0]
                if let file = jetbrainsActiveFile(pid: pid) {
                    return Activity(details: "Editing \(file)", state: "In \(project)", ideName: ide.name, largeImage: key)
                }
                return Activity(details: "Coding", state: "In \(project)", ideName: ide.name, largeImage: key)
            }

        case .generic:
            break
        }

        return Activity(details: "Coding", state: nil, ideName: ide.name, largeImage: key)
    }
}
