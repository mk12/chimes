import AVFoundation
import SwiftUI
import os

@MainActor
class Player: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Player.self)
    )

    // Published so we can change the menu bar icon while playing.
    @Published var isPlaying: Bool = false

    // Parameters controlling chimes MIDI playing.
    @Binding private var volume: Double
    @Binding private var noteDuration: Double
    @Binding private var noteInterval: Double
    @Binding private var phraseInterval: Double
    @Binding private var preStrikeDelay: Double
    @Binding private var strikeDuration: Double
    @Binding private var strikeInterval: Double
    @Binding private var timingAdjustment: Double

    private let music: Music

    var instrument: String {
        didSet {
            prepareInstrument()
            if engine.isRunning {
                needToLoadNewInstrument = true
            } else {
                try! loadInstrument()
            }
        }
    }

    private var needToLoadNewInstrument = false

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var sequencer: AVAudioSequencer
    private var track: AVMusicTrack
    private let bps: Double
    private var currentPlayId = 0
    private var soundFontUrl: URL!
    private var soundFontProgram: UInt8!

    init(
        music: Music,
        instrument: String,
        volume: Binding<Double>,
        noteDuration: Binding<Double>,
        noteInterval: Binding<Double>,
        phraseInterval: Binding<Double>,
        preStrikeDelay: Binding<Double>,
        strikeDuration: Binding<Double>,
        strikeInterval: Binding<Double>,
        timingAdjustment: Binding<Double>,
    ) {
        self.music = music
        self.instrument = instrument
        _volume = volume
        _noteDuration = noteDuration
        _noteInterval = noteInterval
        _phraseInterval = phraseInterval
        _preStrikeDelay = preStrikeDelay
        _strikeDuration = strikeDuration
        _strikeInterval = strikeInterval
        _timingAdjustment = timingAdjustment
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        sequencer = AVAudioSequencer(audioEngine: engine)
        track = sequencer.createAndAppendTrack()
        bps = sequencer.beats(forSeconds: 1)
        prepareInstrument()
        try! loadInstrument()
    }

    private func prepareInstrument() {
        soundFontUrl = Bundle.main.url(
            forResource: instrument,
            withExtension: "sf2"
        )!
        soundFontProgram =
            switch instrument {
            case "Tubular Bells": 16
            case "Lo-Fi Bells": 98
            case "New Age Bells": 88
            default: 0
            }
    }

    private func loadInstrument() throws {
        try sampler.loadSoundBankInstrument(
            at: soundFontUrl,
            program: soundFontProgram,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
    }

    func stop() {
        isPlaying = false
        currentPlayId += 1
        reset()
    }

    private func reset() {
        Self.logger.debug("resetting")
        sequencer.stop()
        sequencer.currentPositionInBeats = 0
        if track.lengthInBeats > 0 {
            // Add one just in case, not sure if it's inclusive
            // (or how that would even make sense with floating point).
            let length = track.lengthInBeats + 1
            track.clearEvents(
                in: AVBeatRange(start: 0, length: length)
            )
        }
        engine.stop()
        engine.reset()
        if needToLoadNewInstrument {
            // Hopefully this will cache the instrument so that
            // loading it is fast the next time.
            try! loadInstrument()
            needToLoadNewInstrument = false
        }
    }

    enum Chime {
        case FirstQuarter
        case HalfHour
        case ThirdQuarter
        case FullHour(Int)
    }

    private enum Note: UInt8 {
        case B3 = 59
        case E4 = 64
        case FSharp4 = 66
        case GSharp4 = 68
        case E3 = 52
    }

    private let P1: [Note] = [.GSharp4, .FSharp4, .E4, .B3]
    private let P2: [Note] = [.E4, .GSharp4, .FSharp4, .B3]
    private let P3: [Note] = [.E4, .FSharp4, .GSharp4, .E4]
    private let P4: [Note] = [.GSharp4, .E4, .FSharp4, .B3]
    private let P5: [Note] = [.B3, .FSharp4, .GSharp4, .E4]

    func play(_ chime: Chime, scheduled: Bool = false) async throws {
        Self.logger.debug("playing chime \(String(describing: chime))")
        // Don't let schedule override manual play.
        if scheduled && isPlaying { return }
        currentPlayId += 1
        let playId = currentPlayId
        reset()
        try loadInstrument()
        addEventsFor(chime: chime)

        isPlaying = true
        engine.prepare()
        sequencer.prepareToPlay()
        let fade = music.isPlaying()
        if fade {
            try await music.fadeOut()
        } else if scheduled {
            try await Task.sleep(
                for: .seconds(music.duration),
                tolerance: .zero,
                clock: .continuous
            )
        }
        guard self.currentPlayId == playId else { return }

        do {
            try engine.start()
            try sequencer.start()
        } catch {
            Self.logger.error("failed to play: \(error)")
            reset()
            return
        }

        try await Task.sleep(
            for: .seconds(track.lengthInSeconds),
            tolerance: .zero,
            clock: .continuous
        )
        guard self.currentPlayId == playId else { return }
        isPlaying = false

        if fade { try await music.fadeIn() }
        guard self.currentPlayId == playId else { return }

        // Let the final note die out for 2 seconds.
        try await Task.sleep(
            for: .seconds(2.0),
            tolerance: .zero,
            clock: .continuous
        )
        guard self.currentPlayId == playId else { return }
        reset()
    }

    func startAhead(chime: Chime) -> TimeInterval {
        let base = timingAdjustment + music.duration
        switch chime {
        case .FirstQuarter, .HalfHour, .ThirdQuarter:
            return base
        case .FullHour:
            return base + self.noteInterval * 12 + self.phraseInterval * 3
                + self.preStrikeDelay
        }
    }

    private func addEventsFor(chime: Chime) {
        let track = sequencer.tracks.first!
        let velocity = UInt32(self.volume * 127)

        // In beats instead of seconds, and cumulative so that
        // we can just add delays at the ends of loops unconditionally.
        let noteDur = self.noteDuration * bps
        let interNote = self.noteInterval * bps
        let interPhrase = self.phraseInterval * bps - interNote
        let preStrike = self.preStrikeDelay * bps - interNote - interPhrase
        let strikeDur = self.strikeDuration * bps
        let interStrike = self.strikeInterval * bps

        let phrases =
            switch chime {
            case .FirstQuarter: [P1]
            case .HalfHour: [P2, P3]
            case .ThirdQuarter: [P4, P5, P1]
            case .FullHour: [P2, P3, P4, P5]
            }

        var time: MusicTimeStamp = 0.0
        for phrase in phrases {
            for note in phrase {
                track.addEvent(event(note, noteDur, velocity), at: time)
                time += interNote
            }
            time += interPhrase
        }
        if case .FullHour(let hour) = chime {
            time += preStrike
            for _ in 0..<hour {
                track.addEvent(event(.E3, strikeDur, velocity), at: time)
                time += interStrike
            }
        }
    }

    private func event(
        _ note: Note,
        _ duration: MusicTimeStamp,
        _ velocity: UInt32
    ) -> AVMIDINoteEvent {
        return AVMIDINoteEvent(
            channel: 0,
            key: UInt32(note.rawValue),
            velocity: velocity,
            duration: duration,
        )
    }
}
