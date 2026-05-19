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
    var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var clientId: String {
        get { UserDefaults.standard.string(forKey: "discordClientId") ?? "1505829653204439190" }
        set { UserDefaults.standard.set(newValue, forKey: "discordClientId") }
    }

    enum ConnectionStatus: Equatable {
        case disconnected, connecting, connected, error(String)
    }

    @ObservationIgnored private let monitor = IDEMonitor()
    // Connection pool: keyed by clientId — connections are reused across IDE switches
    @ObservationIgnored private var rpcClients: [String: DiscordRPCClient] = [:]
    @ObservationIgnored private var activeClientId: String?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let queue = DispatchQueue(label: "com.idecord.rpc", qos: .utility)
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastActiveIDE: IDEInfo?
    @ObservationIgnored private var pendingTick: DispatchWorkItem?
    @ObservationIgnored private var pendingUpdate: DispatchWorkItem?
    @ObservationIgnored private var monitoringStartTime: Date?

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
        monitoringStartTime = Date()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
    }

    func stop() {
        isRunning = false
        monitoringStartTime = nil
        timer?.invalidate(); timer = nil
        pendingTick?.cancel(); pendingTick = nil
        pendingUpdate?.cancel(); pendingUpdate = nil
        queue.async { [weak self] in
            guard let self else { return }
            self.rpcClients.values.forEach { $0.disconnect() }
            self.rpcClients = [:]
            self.activeClientId = nil
            DispatchQueue.main.async { [weak self] in
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
            nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.isAccessibilityGranted = AXIsProcessTrusted()
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

    // MARK: - Internal

    private func debouncedTick() {
        pendingTick?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.tick() }
        pendingTick = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: item)
    }

    private func tick() {
        isAccessibilityGranted = AXIsProcessTrusted()
        refreshRunningBundleIds()
        let enabled = ides.filter { $0.isEnabled }
        let frontmostId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if let frontIDE = enabled.first(where: { $0.id == frontmostId }) {
            lastActiveIDE = frontIDE
        } else if ides.contains(where: { $0.id == frontmostId }) {
            lastActiveIDE = nil
        }

        let frontmostActive = enabled.first(where: { $0.id == frontmostId && runningBundleIds.contains($0.id) })
        let activeIDE = frontmostActive
            ?? lastActiveIDE.flatMap { last in
                enabled.first(where: { $0.id == last.id && runningBundleIds.contains($0.id) })
            }
            ?? enabled.first(where: { runningBundleIds.contains($0.id) })

        let activeClientId = activeIDE.map { ideClientId(for: $0) } ?? clientId
        let startTime = monitoringStartTime

        // AX calls must run on the main thread — capture activity here before going async
        let activePid: pid_t? = activeIDE.flatMap { ide in
            NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == ide.id })?.processIdentifier
        }
        let activity: IDEMonitor.Activity? = activeIDE.flatMap { ide in
            guard let pid = activePid else { return nil }
            return monitor.activity(for: ide, pid: pid)
        }

        // Background queue is only for Discord socket I/O
        pendingUpdate?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.update(clientId: activeClientId, activity: activity, startTime: startTime)
        }
        pendingUpdate = item
        queue.async(execute: item)
    }

    private func update(clientId: String, activity: IDEMonitor.Activity?, startTime: Date?) {
        // No active IDE — clear presence on the previous connection without creating a new one
        if activity == nil {
            if let prevId = activeClientId, let prevClient = rpcClients[prevId], prevClient.isConnected {
                try? prevClient.setActivity(nil)
            }
            activeClientId = nil
            DispatchQueue.main.async {
                self.connectionStatus = .disconnected
                self.currentActivityLabel = nil
            }
            return
        }

        // Get pooled connection or create a new one
        let client: DiscordRPCClient
        if let existing = rpcClients[clientId], existing.isConnected {
            client = existing
        } else {
            rpcClients[clientId]?.disconnect()
            rpcClients[clientId] = nil

            guard !clientId.isEmpty else {
                DispatchQueue.main.async { self.connectionStatus = .error("Discord Client ID not configured") }
                return
            }
            DispatchQueue.main.async { self.connectionStatus = .connecting }
            let newClient = DiscordRPCClient(clientId: clientId)
            do {
                try newClient.connect()
                rpcClients[clientId] = newClient
                client = newClient
                DispatchQueue.main.async { self.connectionStatus = .connected }
            } catch {
                DispatchQueue.main.async { self.connectionStatus = .error(error.localizedDescription) }
                return
            }
        }

        // Switching IDEs — clear presence on the previous connection
        if let prevId = activeClientId, prevId != clientId {
            if let prevClient = rpcClients[prevId], prevClient.isConnected {
                try? prevClient.setActivity(nil)
            }
        }
        activeClientId = clientId

        do {
            let rpc = activity.map {
                RPCActivity(details: $0.details, state: $0.state,
                            largeImage: $0.largeImage, largeText: $0.ideName,
                            startTime: startTime)
            }
            try client.setActivity(rpc)
            let label = activity.map { [$0.details, $0.state].compactMap { $0 }.joined(separator: " · ") }
            DispatchQueue.main.async {
                self.connectionStatus = .connected
                self.currentActivityLabel = label
            }
        } catch {
            rpcClients[clientId]?.disconnect()
            rpcClients[clientId] = nil
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
