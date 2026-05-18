import Foundation
import AppKit
import Observation

@Observable
final class ActivityService {

    var ides: [IDEInfo] = IDEInfo.defaults
    var connectionStatus: ConnectionStatus = .disconnected
    var isRunning = false
    var currentActivityLabel: String?
    var runningBundleIds: Set<String> = []

    var clientId: String {
        get { UserDefaults.standard.string(forKey: "discordClientId") ?? "1505829653204439190" }
        set { UserDefaults.standard.set(newValue, forKey: "discordClientId") }
    }

    enum ConnectionStatus: Equatable {
        case disconnected, connecting, connected, error(String)
    }

    private let monitor = IDEMonitor()
    private var rpcClient: DiscordRPCClient?
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.idecord.rpc", qos: .utility)
    private var observers: [NSObjectProtocol] = []
    private var lastActiveIDE: IDEInfo?
    private var pendingTick: DispatchWorkItem?

    init() {
        loadEnabledStates()
        refreshRunningBundleIds()
        observeWorkspaceNotifications()
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        isRunning = true
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
    }

    func stop() {
        isRunning = false
        timer?.invalidate(); timer = nil
        queue.async { [weak self] in
            self?.rpcClient?.disconnect(); self?.rpcClient = nil
            DispatchQueue.main.async {
                self?.connectionStatus = .disconnected
                self?.currentActivityLabel = nil
            }
        }
    }

    func setEnabled(_ enabled: Bool, for ideId: String) {
        guard let i = ides.firstIndex(where: { $0.id == ideId }) else { return }
        ides[i].isEnabled = enabled
        saveEnabledStates()
    }

    // MARK: - Workspace Observation

    private func observeWorkspaceNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        observers = [
            nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshRunningBundleIds()
            },
            nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshRunningBundleIds()
            },
            // IDE 전환 시 Discord 상태 갱신 (debounce 300ms — 빠른 앱 전환 시 과호출 방지)
            nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                guard self?.isRunning == true else { return }
                self?.debouncedTick()
            },
        ]
    }

    private func refreshRunningBundleIds() {
        let ids = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        runningBundleIds = ids
    }

    // MARK: - Per-IDE Client ID

    func ideClientId(for ide: IDEInfo) -> String {
        UserDefaults.standard.string(forKey: "clientId_\(ide.id)")
            ?? ide.defaultClientId
            ?? clientId
    }

    func setIdeClientId(_ id: String, for bundleId: String) {
        let trimmed = id.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: "clientId_\(bundleId)")
        } else {
            UserDefaults.standard.set(trimmed, forKey: "clientId_\(bundleId)")
        }
    }

    // MARK: - Internal

    private func debouncedTick() {
        pendingTick?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.tick() }
        pendingTick = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func tick() {
        refreshRunningBundleIds()
        let enabled = ides.filter { $0.isEnabled }

        let frontmostId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        // 현재 포커스된 앱이 활성화된 IDE면 마지막 사용 IDE로 기록
        if let frontIDE = enabled.first(where: { $0.id == frontmostId }) {
            lastActiveIDE = frontIDE
        }

        // 우선순위: 마지막 사용 IDE (아직 실행 중) → 실행 중인 첫 번째 IDE
        let activeIDE = lastActiveIDE.flatMap { last in
            enabled.first(where: { $0.id == last.id && runningBundleIds.contains($0.id) })
        } ?? enabled.first(where: { runningBundleIds.contains($0.id) })

        var found: IDEMonitor.Activity?
        var activeClientId = clientId
        if let ide = activeIDE {
            found = monitor.check(ide).activity
            activeClientId = ideClientId(for: ide)
        }

        let id = activeClientId
        let activity = found
        queue.async { [weak self] in self?.update(clientId: id, activity: activity) }
    }

    private func update(clientId: String, activity: IDEMonitor.Activity?) {
        // 활성 IDE가 바뀌어 Client ID가 달라지면 재연결
        if let current = rpcClient, current.isConnected, current.clientId != clientId {
            current.disconnect()
            rpcClient = nil
        }

        if rpcClient == nil || !rpcClient!.isConnected {
            guard !clientId.isEmpty else {
                DispatchQueue.main.async { self.connectionStatus = .error("Discord Client ID not configured") }
                return
            }
            DispatchQueue.main.async { self.connectionStatus = .connecting }
            let client = DiscordRPCClient(clientId: clientId)
            do {
                try client.connect()
                rpcClient = client
                DispatchQueue.main.async { self.connectionStatus = .connected }
            } catch {
                DispatchQueue.main.async { self.connectionStatus = .error(error.localizedDescription) }
                return
            }
        }

        guard let client = rpcClient else { return }
        do {
            let rpc = activity.map { RPCActivity(details: $0.details, state: $0.state, largeImage: $0.largeImage, largeText: $0.ideName) }
            try client.setActivity(rpc)
            let label = activity.map { [$0.details, $0.state].compactMap { $0 }.joined(separator: " · ") }
            DispatchQueue.main.async {
                self.connectionStatus = .connected
                self.currentActivityLabel = label
            }
        } catch {
            rpcClient?.disconnect(); rpcClient = nil
            DispatchQueue.main.async {
                self.connectionStatus = .error(error.localizedDescription)
                self.currentActivityLabel = nil
            }
        }
    }

    // MARK: - Persistence

    private func loadEnabledStates() {
        for i in ides.indices {
            let key = "ide_enabled_\(ides[i].id)"
            if UserDefaults.standard.object(forKey: key) != nil {
                ides[i].isEnabled = UserDefaults.standard.bool(forKey: key)
            }
        }
    }

    private func saveEnabledStates() {
        for ide in ides {
            UserDefaults.standard.set(ide.isEnabled, forKey: "ide_enabled_\(ide.id)")
        }
    }
}
