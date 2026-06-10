import Foundation

enum SIPTransport: String, CaseIterable, Identifiable, Codable {
    case udp = "UDP"
    case tcp = "TCP"
    case tls = "TLS"

    var id: String { rawValue }
}

struct SIPAccount: Codable, Equatable {
    var username: String
    var domain: String
    var port: Int
    var transport: SIPTransport

    var registrarURI: String {
        "sip:\(domain):\(port);transport=\(transport.rawValue.lowercased())"
    }

    var accountURI: String {
        "sip:\(username)@\(domain)"
    }
}

enum RegistrationState: Equatable {
    case unconfigured
    case unregistered
    case registering
    case registered
    case failed(String)

    var displayText: String {
        switch self {
        case .unconfigured: "Not Configured"
        case .unregistered: "Unregistered"
        case .registering: "Registering"
        case .registered: "Registered"
        case .failed(let reason): "Failed: \(reason)"
        }
    }
}

enum CallDirection: String, Codable, CaseIterable, Identifiable {
    case incoming
    case outgoing
    case missed

    var id: String { rawValue }
}

enum SoftphoneCallState: String, Codable {
    case idle
    case incoming
    case calling
    case ringing
    case connecting
    case connected
    case held
    case ended
    case failed
}

struct ActiveCall: Identifiable, Equatable {
    let id: Int32
    var remoteURI: String
    var displayName: String
    var direction: CallDirection
    var state: SoftphoneCallState
    var startedAt: Date?
    var connectedAt: Date?
    var endedAt: Date?
    var isMuted: Bool
    var isHeld: Bool

    var duration: TimeInterval {
        guard let connectedAt else { return 0 }
        return (endedAt ?? Date()).timeIntervalSince(connectedAt)
    }
}

struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: Int32
    let name: String
    let inputChannels: Int
    let outputChannels: Int
}

struct CallHistoryEntry: Identifiable, Codable, Equatable {
    let id: Int64
    let remoteURI: String
    let displayName: String
    let direction: CallDirection
    let duration: TimeInterval
    let timestamp: Date
}

struct LogEntry: Identifiable, Codable, Equatable {
    enum Category: String, Codable {
        case sip
        case registration
        case call
        case audio
        case error
    }

    let id: UUID
    let category: Category
    let message: String
    let timestamp: Date
}
