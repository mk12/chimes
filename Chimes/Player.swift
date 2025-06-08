import AVFoundation
import SwiftUI

@MainActor
class Player: ObservableObject {
    @Published var isPlaying: Bool = false

    @Binding private var noteLength: Double
    @Binding private var interNoteDelay: Double
    @Binding private var interPhraseDelay: Double
    @Binding private var preStrikeDelay: Double
    @Binding private var strikeDuration: Double
    @Binding private var interStrikeDelay: Double

    private var engine: AVAudioEngine?
    private let music: Music
    private var currentPlayId = 0
    private let soundFontUrl = Bundle.main.url(
        forResource: "Tubular Bells",
        withExtension: "sf2"
    )!

    init(
        music: Music,
        noteLength: Binding<Double>,
        interNoteDelay: Binding<Double>,
        interPhraseDelay: Binding<Double>,
        preStrikeDelay: Binding<Double>,
        strikeDuration: Binding<Double>,
        interStrikeDelay: Binding<Double>,
    ) {
        self.music = music
        _noteLength  = noteLength
        _interNoteDelay  = interNoteDelay
        _interPhraseDelay  = interPhraseDelay
        _preStrikeDelay  = preStrikeDelay
        _strikeDuration  = strikeDuration
        _interStrikeDelay  = interStrikeDelay
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        engine?.stop()
        engine?.reset()
//        engine = nil
    }

    enum Chime {
        case FirstQuarter
        case HalfHour
        case ThirdQuarter
        case FullHour(Int)
    }

    func play(_ chime: Chime) async throws {
        switch chime {
        case .FirstQuarter: try await play(phrases: [P1])
        case .HalfHour: try await play(phrases: [P2, P3])
        case .ThirdQuarter: try await play(phrases: [P4, P5, P1])
        case .FullHour(let hour):
            try await play(phrases: [P2, P3, P4, P5], hour: hour)
        }
    }

    private func load() throws -> (AVAudioEngine, AVAudioSequencer) {
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        let sequencer = AVAudioSequencer(audioEngine: engine)
        try sampler.loadSoundBankInstrument(
            at: soundFontUrl,
            program: 16,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
        self.engine = engine
        return (engine, sequencer)
    }

    /// MIDI-note helpers (E-major Westminster bells).
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

    private func play(phrases: [[Note]], hour: Int? = nil) async throws {
        currentPlayId += 1
        let playId = currentPlayId

        let noteLength: MusicTimeStamp = 2.0
        let interNoteDelay: MusicTimeStamp = 1.5
        let interPhraseDelay: MusicTimeStamp = 1.75
        let beforeStrikeDelay: MusicTimeStamp = 2.5
        let interStrikeDelay: MusicTimeStamp = 5.0

        stop()
        let (engine, sequencer) = try load()
        let track = sequencer.createAndAppendTrack()
        var time: MusicTimeStamp = 0.0
        for phrase in phrases {
            for note in phrase {
                track.addEvent(makeEvent(note, noteLength), at: time)
                time += interNoteDelay
            }
            time += interPhraseDelay
        }
        if let hour {
            time += beforeStrikeDelay
            for _ in 0..<hour {
                track.addEvent(makeEvent(.E3, noteLength), at: time)
                time += interStrikeDelay
            }
        }

        isPlaying = true
        engine.prepare()
        sequencer.prepareToPlay()
        let fade = music.isPlaying()
        if fade {
            try await music.fadeOut()
        }

        do {
            try engine.start()
            try sequencer.start()
        } catch {
            print("Failed to play: \(error)")
            stop()
            return
        }

        try await Task.sleep(for: .seconds(sequencer.seconds(forBeats: time)))
        guard self.currentPlayId == playId else { return }
        isPlaying = false
        if fade { try await music.fadeIn() }

        try await Task.sleep(for: .seconds(2.0))
        guard self.currentPlayId == playId else { return }
        sequencer.stop()
        self.stop()
    }

    private func makeEvent(_ note: Note, _ length: MusicTimeStamp)
        -> AVMIDINoteEvent
    {
        return AVMIDINoteEvent(
            channel: 0,
            key: UInt32(note.rawValue),
            velocity: 127,
            duration: length
        )
    }
}
