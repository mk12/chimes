import AVFoundation

class Player {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let sequencer: AVAudioSequencer
    private let soundFontUrl = Bundle.main.url(
        forResource: "Tubular Bells",
        withExtension: "sf2"
    )!
    private var currentPlayId = 0

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        sequencer = AVAudioSequencer(audioEngine: engine)
    }

    func playFirstQuarter() {
        play([P1])
    }

    func playHalfHour() {
        play([P2, P3])
    }

    func playThirdQuarter() {
        play([P4, P5, P1])
    }

    /// - Parameter hour: 1–12 in the current cycle
    ///   (use `Calendar.current.component(.hour, from: Date())`)
    func playHour(_ hour: Int) {
        play([P2, P3, P4, P5], hour: hour)
    }

    func stop() {
        sequencer.stop()
        sequencer.currentPositionInBeats = 0
        engine.stop()
        engine.reset()
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

    private func play(_ phrases: [[Note]], hour: Int? = nil) {
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

        do {
            try engine.start()
            try loadSountFont()
            try sequencer.start()
        } catch {
            print("Failed to play: \(error)")
        }

        let extraSlack = 2.0
        let duration = sequencer.seconds(forBeats: time) + extraSlack
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            [weak self] in
            guard let self else { return }
            if self.currentPlayId == playId {
                self.stop()
            }
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
