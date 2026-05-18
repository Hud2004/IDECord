import Foundation

/// Communicates with Discord via its local Unix-domain IPC socket.
final class DiscordRPCClient: @unchecked Sendable {

    private var socketFd: Int32 = -1
    let clientId: String
    private(set) var sessionStartTime: Date?

    var isConnected: Bool { socketFd != -1 }

    private enum Opcode: UInt32 {
        case handshake = 0, frame = 1, close = 2
    }

    enum RPCError: LocalizedError {
        case socketNotFound, socketCreationFailed, connectionFailed(Int32), sendFailed, readFailed

        var errorDescription: String? {
            switch self {
            case .socketNotFound:           return "Discord is not running"
            case .socketCreationFailed:     return "Failed to create socket"
            case .connectionFailed(let e):  return "Connection failed (errno \(e))"
            case .sendFailed:               return "Failed to send data to Discord"
            case .readFailed:               return "Failed to read Discord response"
            }
        }
    }

    init(clientId: String) {
        self.clientId = clientId
    }

    // MARK: - Public API

    func connect() throws {
        guard let path = discordSocketPath() else { throw RPCError.socketNotFound }

        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd != -1 else { throw RPCError.socketCreationFailed }

        var tv = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            path.utf8.prefix(103).enumerated().forEach { buf[$0.offset] = $0.element }
        }

        let rc = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard rc == 0 else {
            let e = errno; Darwin.close(socketFd); socketFd = -1
            throw RPCError.connectionFailed(e)
        }

        try send(opcode: .handshake, payload: ["v": 1, "client_id": clientId])
        try readPacket()    // expect READY
        sessionStartTime = Date()
    }

    func disconnect() {
        guard socketFd != -1 else { return }
        Darwin.close(socketFd); socketFd = -1
        sessionStartTime = nil
    }

    func setActivity(_ activity: RPCActivity?) throws {
        var args: [String: Any] = ["pid": Int(ProcessInfo.processInfo.processIdentifier)]
        if let a = activity {
            var dict: [String: Any] = ["details": a.details]
            if let s = a.state { dict["state"] = s }
            if let t = sessionStartTime { dict["timestamps"] = ["start": Int(t.timeIntervalSince1970)] }
            dict["assets"] = ["large_image": a.largeImage, "large_text": a.largeText]
            args["activity"] = dict
        }
        let payload: [String: Any] = ["cmd": "SET_ACTIVITY", "args": args, "nonce": UUID().uuidString]
        try send(opcode: .frame, payload: payload)
        try? readPacket()   // 응답은 non-critical — 타임아웃으로 연결이 끊기지 않도록
    }

    // MARK: - Private

    private func send(opcode: Opcode, payload: [String: Any]) throws {
        let json = try JSONSerialization.data(withJSONObject: payload)
        var op = opcode.rawValue.littleEndian
        var len = UInt32(json.count).littleEndian
        var packet = Data(bytes: &op, count: 4)
        packet.append(Data(bytes: &len, count: 4))
        packet.append(json)
        let n = packet.withUnsafeBytes { Darwin.send(socketFd, $0.baseAddress!, packet.count, 0) }
        guard n == packet.count else { throw RPCError.sendFailed }
    }

    @discardableResult
    private func readPacket() throws -> Data {
        var header = [UInt8](repeating: 0, count: 8)
        guard recv(socketFd, &header, 8, MSG_WAITALL) == 8 else { throw RPCError.readFailed }
        let length = Int(UInt32(header[4]) | UInt32(header[5]) << 8 | UInt32(header[6]) << 16 | UInt32(header[7]) << 24)
        guard length >= 0, length < 65536 else { throw RPCError.readFailed }
        var body = [UInt8](repeating: 0, count: length)
        guard recv(socketFd, &body, length, MSG_WAITALL) == length else { throw RPCError.readFailed }
        return Data(body)
    }

    private func discordSocketPath() -> String? {
        let tmp = NSTemporaryDirectory()
        for i in 0..<10 {
            let path = tmp + "discord-ipc-\(i)"
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }
}

struct RPCActivity {
    let details: String
    let state: String?
    let largeImage: String
    let largeText: String
}
