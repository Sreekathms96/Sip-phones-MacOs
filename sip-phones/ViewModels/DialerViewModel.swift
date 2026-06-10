import Foundation
import SwiftUI

@MainActor
final class DialerViewModel: ObservableObject {
    @Published var number = ""
    @AppStorage("lastDialedNumber") private var lastDialedNumber = ""

    private let sipService = SIPService.shared

    let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]

    func append(_ digit: String) {
        number.append(digit)
    }

    func backspace() {
        if !number.isEmpty { number.removeLast() }
    }

    func call() {
        let target = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        lastDialedNumber = target
        sipService.makeCall(to: target)
    }

    func redial() {
        guard !lastDialedNumber.isEmpty else { return }
        number = lastDialedNumber
        sipService.makeCall(to: lastDialedNumber)
    }
}
