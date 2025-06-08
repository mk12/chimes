import Foundation
import ScriptingBridge
import SwiftUI

class Music {
    private let musicApp = SBApplication(bundleIdentifier: "com.apple.Music")!

    @Binding var enabled: Bool
    @Binding var duration: Double

    init(enabled: Binding<Bool>, duration: Binding<Double>) {
        _enabled = enabled
        _duration = duration
    }

    func isPlaying() -> Bool {
        if !enabled { return false }
        let state = musicApp.value(forKey: "playerState")! as! UInt32
        return UnicodeScalar(state & 0xff) == UnicodeScalar("P")
    }

    func fadeOut() async throws {
        try await slideVolume(to: 0)
        musicApp.perform(NSSelectorFromString("pause"))
    }

    func fadeIn() async throws {
        // "playpause" seems more reliable than "resume"
        musicApp.perform(NSSelectorFromString("playpause"))
        try await slideVolume(to: 100)
    }

    private func slideVolume(to: Int) async throws {
        let n = 20
        let from = 100 - to
        let step = (to - from) / n
        let sleep = .seconds(duration) / n
        for i in 0...n {
            musicApp.setValue(from + step * i, forKey: "soundVolume")
            try await Task.sleep(for: sleep)
        }
    }
}
