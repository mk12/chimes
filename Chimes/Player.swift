import AVFoundation

class Player {
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let sequencer: AVAudioSequencer

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        self.sequencer = AVAudioSequencer(audioEngine: engine)
        do {
            try engine.start()
            try loadSoundFont()
        } catch {
            print("Failed to start engine: \(error)")
        }
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

    private func loadSoundFont() throws {
        guard
            let url = Bundle.main.url(
                forResource: "Tubular Bells",
                withExtension: "sf2"
            )
        else {
            throw NSError(domain: "SoundFontNotFound", code: 1, userInfo: nil)
        }
        try sampler.loadSoundBankInstrument(
            at: url,
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
        let noteLength = 1.0
        let interNoteDelay = 0.8
        let interPhraseDelay = 1.0
        let beforeStrikeDelay = 1.0
        let interStrikeDelay = 2.0

        var t = DispatchTime.now()
        for notes in phrases {
            for note in notes {
                playNote(note, at: t, length: noteLength)
                t = t + interNoteDelay
            }
            t = t + interPhraseDelay
        }

        if let hour {
            t = t + beforeStrikeDelay
            for _ in 0..<hour {
                playNote(.E3, at: t, length: noteLength)
                t = t + interStrikeDelay
            }
        }
    }

    private func playNote(_ note: Note, at: DispatchTime, length: Double) {
        self.queue.asyncAfter(deadline: at) { [weak self] in
            guard let self else { return }
            self.sampler.startNote(
                note.rawValue,
                withVelocity: 127,
                onChannel: 0
            )
        }
        self.queue.asyncAfter(deadline: at + length) { [weak self] in
            guard let self else { return }
            self.sampler.stopNote(note.rawValue, onChannel: 0)
        }
    }
}
