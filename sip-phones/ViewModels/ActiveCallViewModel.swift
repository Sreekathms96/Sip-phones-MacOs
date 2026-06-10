import Foundation

@MainActor
final class ActiveCallViewModel: ObservableObject {
    @Published var dtmfDigits = ""
    private let sipService = SIPService.shared

    func accept(_ call: ActiveCall) {
        sipService.answer(callId: call.id)
    }

    func reject(_ call: ActiveCall) {
        sipService.reject(callId: call.id)
    }

    func hangup(_ call: ActiveCall) {
        sipService.hangup(callId: call.id)
    }

    func toggleMute(_ call: ActiveCall) {
        sipService.setMuted(!call.isMuted, callId: call.id)
    }

    func toggleHold(_ call: ActiveCall) {
        sipService.setHeld(!call.isHeld, callId: call.id)
    }

    func sendDTMF(_ digit: String, call: ActiveCall) {
        sipService.sendDTMF(digit, callId: call.id)
        dtmfDigits.append(digit)
    }
}
