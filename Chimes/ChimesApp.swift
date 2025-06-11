import SwiftUI

@main
struct ChimesApp: App {
    @AppStorage("enabled") private var enabled: Bool = true
    @AppStorage("fadeMusic") private var fadeMusic: Bool = true

    @AppStorage("instrument") private var instrument: String = "Bronze Bells"

    @AppStorage("volume") private var volume = 1.0
    @AppStorage("noteDuration") private var noteDuration = 1.0
    @AppStorage("noteInterval") private var noteInterval = 0.75
    @AppStorage("phraseInterval") private var phraseInterval = 1.6
    @AppStorage("preStrikeDelay") private var preStrikeDelay = 2.1
    // It's important that strikeDuration <= strikeInterval, otherwise for some
    // instruments all but the first strike become very short and quiet because
    // it reuses the same note (not an issue for the other chimes because they
    // never have the same note twice in a row).
    @AppStorage("strikeDuration") private var strikeDuration = 2.5
    @AppStorage("strikeInterval") private var strikeInterval = 2.5
    @AppStorage("fadeMusicDuration") private var fadeMusicDuration = 1.0
    @AppStorage("timingAdjustment") private var timingAdjustment = 0.3
    @AppStorage("fadeMusicAdjustment") private var fadeMusicAdjustment = 0.3

    @ObservedObject private var player: Player
    private let scheduler: Scheduler

    @Environment(\.openSettings) private var openSettings

    private let instruments = [
        "Bronze Bells",
        "Tubular Bells",
        "American Bells",
        "Lo-Fi Bells",
        "New Age Bells",
    ]

    init() {
        if !instruments.contains(_instrument.wrappedValue) {
            _instrument.wrappedValue = instruments[0]
        }
        let music = Music(
            enabled: _fadeMusic.projectedValue,
            duration: _fadeMusicDuration.projectedValue,
            adjustment: _fadeMusicAdjustment.projectedValue,
        )
        let player = Player(
            music: music,
            instrument: _instrument.wrappedValue,
            volume: _volume.projectedValue,
            noteDuration: _noteDuration.projectedValue,
            noteInterval: _noteInterval.projectedValue,
            phraseInterval: _phraseInterval.projectedValue,
            preStrikeDelay: _preStrikeDelay.projectedValue,
            strikeDuration: _strikeDuration.projectedValue,
            strikeInterval: _strikeInterval.projectedValue,
            timingAdjustment: _timingAdjustment.projectedValue,
        )
        self.player = player
        scheduler = Scheduler(player: player)
        scheduler.enabled = enabled
    }

    private func image() -> String {
        if player.isPlaying {
            return "bell.fill"
        }
        if !enabled {
            return "bell.slash"
        }
        return "bell"
    }

    var body: some Scene {
        let instrumentPicker = Picker("Instrument", selection: $instrument) {
            ForEach(instruments, id: \.self) { Text($0) }
        }
        MenuBarExtra("Chimes", systemImage: image()) {
            Toggle("Enable Chimes", isOn: $enabled)
            instrumentPicker
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
            Button("Settings...") {
                openSettings()
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .onChange(of: enabled) {
            scheduler.enabled = enabled
        }
        .onChange(of: instrument) {
            player.instrument = instrument
        }

        Settings {
            SettingsView(
                scheduler: scheduler,
                instrumentPicker: instrumentPicker,
                enabled: $enabled,
                volume: $volume,
                fadeMusic: $fadeMusic,
                noteDuration: $noteDuration,
                noteInterval: $noteInterval,
                phraseInterval: $phraseInterval,
                preStrikeDelay: $preStrikeDelay,
                strikeDuration: $strikeDuration,
                strikeInterval: $strikeInterval,
                fadeMusicDuration: $fadeMusicDuration,
                timingAdjustment: $timingAdjustment,
                fadeMusicAdjustment: $fadeMusicAdjustment,
            )
        }
    }
}
