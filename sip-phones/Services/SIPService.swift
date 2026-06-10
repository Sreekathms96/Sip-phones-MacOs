import Foundation

@MainActor
final class SIPService: NSObject, ObservableObject {
    static let shared = SIPService()

    @Published private(set) var registrationState: RegistrationState = .unconfigured
    @Published private(set) var activeCalls: [ActiveCall] = []

    private let bridge = PJSIPBridge.shared()
    private let logger = LogManager.shared
    private var account: SIPAccount?
    private var password: String?

    override private init() {
        super.init()
        bridge.delegate = self
    }

    func start(debugLogging: Bool) {
        do {
            try bridge.start(withLogLevel: debugLogging ? 5 : 3)
            logger.append(.sip, "PJSIP started")
        } catch {
            registrationState = .failed(error.localizedDescription)
            logger.append(.error, error.localizedDescription)
        }
    }

    func configureAndRegister(account: SIPAccount, password: String) {
        self.account = account
        self.password = password
        registrationState = .registering
        do {
            try bridge.configureAccount(
                withUsername: account.username,
                password: password,
                domain: account.domain,
                port: Int32(account.port),
                transport: account.transport.rawValue
            )
            logger.append(.registration, "Registration requested for \(account.accountURI)")
        } catch {
            registrationState = .failed(error.localizedDescription)
            logger.append(.error, error.localizedDescription)
        }
    }

    func unregister() {
        do {
            try bridge.unregisterAccount()
            registrationState = .unregistered
            logger.append(.registration, "Unregister requested")
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func makeCall(to destination: String) {
        guard let account else { return }
        do {
            try bridge.makeCall(to: destination, domain: account.domain, port: Int32(account.port), transport: account.transport.rawValue)
            logger.append(.call, "Outgoing call requested to \(destination)")
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func answer(callId: Int32) {
        do {
            try bridge.answerCall(callId)
            updateCall(callId: callId) { call in
                call.state = .connecting
            }
            logger.append(.call, "Answered call \(callId)")
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func reject(callId: Int32) {
        do {
            try bridge.rejectCall(callId)
            finishCall(callId: callId, missed: true)
            logger.append(.call, "Rejected call \(callId)")
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func hangup(callId: Int32) {
        do {
            try bridge.hangupCall(callId)
            finishCall(callId: callId, missed: false)
            logger.append(.call, "Hung up call \(callId)")
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func setMuted(_ muted: Bool, callId: Int32) {
        do {
            try bridge.setMuted(muted, callId: callId)
            updateCall(callId: callId) { $0.isMuted = muted }
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func setHeld(_ held: Bool, callId: Int32) {
        do {
            try bridge.setHold(held, callId: callId)
            updateCall(callId: callId) {
                $0.isHeld = held
                $0.state = held ? .held : .connected
            }
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    func sendDTMF(_ digit: String, callId: Int32) {
        do {
            try bridge.sendDTMF(digit, callId: callId)
        } catch {
            logger.append(.error, error.localizedDescription)
        }
    }

    private func updateCall(callId: Int32, mutation: (inout ActiveCall) -> Void) {
        guard let index = activeCalls.firstIndex(where: { $0.id == callId }) else { return }
        mutation(&activeCalls[index])
    }

    private func upsertCall(_ call: ActiveCall) {
        if let index = activeCalls.firstIndex(where: { $0.id == call.id }) {
            activeCalls[index] = call
        } else {
            activeCalls.append(call)
        }
    }

    private func finishCall(callId: Int32, missed: Bool) {
        guard let call = activeCalls.first(where: { $0.id == callId }) else { return }
        let ended = Date()
        let duration = call.connectedAt.map { ended.timeIntervalSince($0) } ?? 0
        let direction: CallDirection = missed ? .missed : call.direction
        do {
            try DatabaseManager.shared.insertHistory(
                remoteURI: call.remoteURI,
                displayName: call.displayName,
                direction: direction,
                duration: duration,
                timestamp: call.startedAt ?? ended
            )
        } catch {
            logger.append(.error, error.localizedDescription)
        }
        activeCalls.removeAll { $0.id == callId }
    }
}

extension SIPService: PJSIPBridgeDelegate {
    nonisolated func pjsipRegistrationChanged(_ isRegistered: Bool, statusCode: Int, reason: String) {
        Task { @MainActor in
            registrationState = isRegistered ? .registered : .failed(reason.isEmpty ? "SIP \(statusCode)" : reason)
            logger.append(.registration, "Registration changed: \(registrationState.displayText)")
        }
    }

    nonisolated func pjsipIncomingCall(_ callId: Int32, remoteURI: String, displayName: String) {
        Task { @MainActor in
            let call = ActiveCall(
                id: callId,
                remoteURI: remoteURI,
                displayName: displayName,
                direction: .incoming,
                state: .incoming,
                startedAt: Date(),
                connectedAt: nil,
                endedAt: nil,
                isMuted: false,
                isHeld: false
            )
            upsertCall(call)
            NotificationManager.shared.notifyIncomingCall(displayName: displayName, remoteURI: remoteURI)
            logger.append(.call, "Incoming call from \(remoteURI)")
        }
    }

    nonisolated func pjsipCallStateChanged(_ callId: Int32, state: String, statusCode: Int, reason: String) {
        Task { @MainActor in
            let mappedState = SoftphoneCallState(rawValue: state) ?? .failed
            if let index = activeCalls.firstIndex(where: { $0.id == callId }) {
                activeCalls[index].state = mappedState
                if mappedState == .connected && activeCalls[index].connectedAt == nil {
                    activeCalls[index].connectedAt = Date()
                }
                if mappedState == .ended || mappedState == .failed {
                    finishCall(callId: callId, missed: activeCalls[index].direction == .incoming && activeCalls[index].connectedAt == nil)
                }
            } else if mappedState == .calling || mappedState == .ringing || mappedState == .connecting {
                upsertCall(ActiveCall(
                    id: callId,
                    remoteURI: "",
                    displayName: "Outbound Call",
                    direction: .outgoing,
                    state: mappedState,
                    startedAt: Date(),
                    connectedAt: nil,
                    endedAt: nil,
                    isMuted: false,
                    isHeld: false
                ))
            }
            logger.append(.call, "Call \(callId) state \(state) \(statusCode) \(reason)")
        }
    }

    nonisolated func pjsipCallMediaActive(_ callId: Int32) {
        Task { @MainActor in
            updateCall(callId: callId) {
                $0.state = .connected
                if $0.connectedAt == nil { $0.connectedAt = Date() }
            }
        }
    }

    nonisolated func pjsipLogMessage(_ message: String, level: Int) {
        Task { @MainActor in
            logger.append(.sip, message)
        }
    }
}
