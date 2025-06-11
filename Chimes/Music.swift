import Foundation
import ScriptingBridge
import SwiftUI
import os

class Music {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Music.self)
    )

    private let musicApp = SBApplication(bundleIdentifier: "com.apple.Music")!

    @Binding private var enabled: Bool
    @Binding private var adjustment: Double

    @Binding var duration: Double

    init(
        enabled: Binding<Bool>,
        duration: Binding<Double>,
        adjustment: Binding<Double>,
    ) {
        _enabled = enabled
        _duration = duration
        _adjustment = adjustment
    }

    func isPlaying() -> Bool {
        if !enabled { return false }
        let state = musicApp.value(forKey: "playerState")! as! UInt32
        return UnicodeScalar(state & 0xff) == UnicodeScalar("P")
    }

    func fadeOut() async throws {
        Self.logger.debug("fading out music")
        try await slideVolume(to: 0)
        musicApp.perform(NSSelectorFromString("pause"))
    }

    func fadeIn() async throws {
        Self.logger.debug("fading in music")
        // "playpause" seems more reliable than "resume"
        musicApp.perform(NSSelectorFromString("playpause"))
        try await slideVolume(to: 100)
    }

    private func slideVolume(to: Int) async throws {
        let n = 20
        let from = 100 - to
        let step = (to - from) / n
        // Subtract the adjustment to account for other CPU activity
        // besides the sleeps contributing to duration.
        let sleep = .seconds(duration - adjustment) / n
        for i in 0...n {
            musicApp.setValue(from + step * i, forKey: "soundVolume")
            try await Task.sleep(
                for: sleep,
                tolerance: .zero,
                clock: .continuous
            )
        }
    }
}
