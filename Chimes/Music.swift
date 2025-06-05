import Foundation

class Music {
    private let isPlayingScript = NSAppleScript(
        source: """
            tell application "Music" to get player state
            """
    )!

    private let fadeOutScript = NSAppleScript(
        source: """
            tell application "Music"
                repeat with i from 1 to 20
                    set sound volume to 100 - (i * 5)
                    delay 0.05
                end repeat
                pause
            end tell
            """
    )!

    private let fadeInScript = NSAppleScript(
        source: """
            tell application "Music"
                play
                repeat with i from 1 to 20
                    set sound volume to (i * 5)
                    delay 0.05
                end repeat
            end tell
            """
    )!

    init() {
        isPlayingScript.compileAndReturnError(nil)
        fadeOutScript.compileAndReturnError(nil)
        fadeInScript.compileAndReturnError(nil)
    }

    func isPlaying() -> Bool {
        // With osascript in the terminal it's "playing" or "paused".
        // Here for some reason it's either "kPSP" or "kPSp".
        return exec(isPlayingScript) == "kPSP"
    }

    func fadeOut() { _ = exec(fadeOutScript) }
    func fadeIn() { _ = exec(fadeInScript) }

    private func exec(_ script: NSAppleScript) -> String? {
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let error {
            print(error)
            return nil
        }
        return output.stringValue
    }
}
