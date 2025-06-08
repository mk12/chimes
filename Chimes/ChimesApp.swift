import SwiftUI

@main
struct ChimesApp: App {
    @AppStorage("enabled") private var enabled: Bool = true

    @AppStorage("fadeOutMusic") private var fadeOutMusic: Bool = true
    @AppStorage("fadeOutMusicDuration") private var fadeOutMusicDuration:
        Double = 1.0

    @AppStorage("noteLength") private var noteLength = 1.0
    @AppStorage("interNoteDelay") private var interNoteDelay = 0.75
    @AppStorage("interPhraseDelay") private var interPhraseDelay = 1.6
    @AppStorage("preStrikeDelay") private var preStrikeDelay = 2.1
    @AppStorage("strikeDuration") private var strikeDuration = 1.0
    @AppStorage("interStrikeDelay") private var interStrikeDelay = 2.5

    @ObservedObject private var player: Player
    private let scheduler: Scheduler

    init() {
        let music = Music(
            enabled: _fadeOutMusic.projectedValue,
            duration: _fadeOutMusicDuration.projectedValue
        )
        let player = Player(
            music: music,
            noteLength: _noteLength.projectedValue,
            interNoteDelay: _interNoteDelay.projectedValue,
            interPhraseDelay: _interPhraseDelay.projectedValue,
            preStrikeDelay: _preStrikeDelay.projectedValue,
            strikeDuration: _strikeDuration.projectedValue,
            interStrikeDelay: _interStrikeDelay.projectedValue,
        )
        self.player = player
        scheduler = Scheduler(player: player)
        scheduler.enabled = enabled
    }

    private func image() -> String {
        if !enabled {
            return "bell.slash"
        }
        if player.isPlaying {
            return "bell.fill"
        }
        return "bell"
    }

    var body: some Scene {
        MenuBarExtra("Chimes", systemImage: image()) {
            Toggle("Enable Chimes", isOn: $enabled)
            Menu("Play Now") {
                Button("First Quarter") {
                    Task { try await player.play(.FirstQuarter) }
                }
                Button("Half Hour") {
                    Task { try await player.play(.HalfHour) }
                }
                Button("Third Quarter") {
                    Task { try await player.play(.ThirdQuarter) }
                }
                Menu("Full Hour") {
                    ForEach(1...12, id: \.self) { hour in
                        Button("\(hour)") {
                            Task { try await player.play(.FullHour(hour)) }
                        }
                    }
                }
            }
            Divider()
            SettingsLink()
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onChange(of: enabled) {
            scheduler.enabled = enabled
        }

        Settings {
            SettingsView(
                enabled: $enabled,
                fadeOutMusic: $fadeOutMusic,
                fadeOutMusicDuration: $fadeOutMusicDuration,
                noteLength: $noteLength,
                interNoteDelay: $interNoteDelay,
                interPhraseDelay: $interPhraseDelay,
                preStrikeDelay: $preStrikeDelay,
                strikeDuration: $strikeDuration,
                interStrikeDelay: $interStrikeDelay,
            )
        }
    }
}
