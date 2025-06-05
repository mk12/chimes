import AVFoundation

class Player: ObservableObject {
    @Published var isPlaying: Bool = false

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let sequencer: AVAudioSequencer
    private let music = Music()
    private var currentPlayId = 0
    private let soundFontUrl = Bundle.main.url(
        forResource: "Tubular Bells",
        withExtension: "sf2"
    )!

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        sequencer = AVAudioSequencer(audioEngine: engine)
    }

    func stop() {
        isPlaying = false
        sequencer.stop()
        sequencer.currentPositionInBeats = 0
        engine.stop()
        engine.reset()
    }

    enum Chime {
        case FirstQuarter
        case HalfHour
        case ThirdQuarter
        case FullHour(Int)
    }

    func play(_ chime: Chime) {
        switch chime {
        case .FirstQuarter: play(phrases: [P1])
        case .HalfHour: play(phrases: [P2, P3])
        case .ThirdQuarter: play(phrases: [P4, P5, P1])
        case .FullHour(let hour): play(phrases: [P2, P3, P4, P5], hour: hour)
        }
    }

    private func loadSountFont() throws {
        try sampler.loadSoundBankInstrument(
            at: soundFontUrl,
            program: 16,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
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

    private func play(phrases: [[Note]], hour: Int? = nil) {
        currentPlayId += 1
        let playId = currentPlayId

        let noteLength: MusicTimeStamp = 2.0
        let interNoteDelay: MusicTimeStamp = 1.75
        let interPhraseDelay: MusicTimeStamp = 1.75
        let beforeStrikeDelay: MusicTimeStamp = 2.5
        let interStrikeDelay: MusicTimeStamp = 5.0

        stop()
        while let track = sequencer.tracks.first {
            sequencer.removeTrack(track)
        }

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
        let fadeMusic = music.isPlaying()
        if fadeMusic {
            music.fadeOut()
        }

        do {
            try engine.start()
            try loadSountFont()
            try sequencer.start()
        } catch {
            print("Failed to play: \(error)")
            stop()
            return
        }

        let duration = sequencer.seconds(forBeats: time)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            [weak self] in
            guard let self else { return }
            guard self.currentPlayId == playId else { return }
            isPlaying = false
            if fadeMusic { music.fadeIn() }
        }
        let extraSlack = 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + extraSlack)
        {
            [weak self] in
            guard let self else { return }
            guard self.currentPlayId == playId else { return }
            self.stop()
        }
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
