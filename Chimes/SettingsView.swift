import SwiftUI

struct SettingsView: View {
    @Binding private var enabled: Bool
    @Binding private var volume: Double

    @Binding private var fadeOutMusic: Bool
    @Binding private var fadeOutMusicDuration: Double

    @Binding private var noteDuration: Double
    @Binding private var interNoteDelay: Double
    @Binding private var interPhraseDelay: Double
    @Binding private var preStrikeDelay: Double
    @Binding private var strikeDuration: Double
    @Binding private var interStrikeDelay: Double

    init(
        enabled: Binding<Bool>,
        volume: Binding<Double>,
        fadeOutMusic: Binding<Bool>,
        fadeOutMusicDuration: Binding<Double>,
        noteDuration: Binding<Double>,
        interNoteDelay: Binding<Double>,
        interPhraseDelay: Binding<Double>,
        preStrikeDelay: Binding<Double>,
        strikeDuration: Binding<Double>,
        interStrikeDelay: Binding<Double>,
    ) {
        _enabled = enabled
        _volume = volume
        _fadeOutMusic = fadeOutMusic
        _fadeOutMusicDuration = fadeOutMusicDuration
        _noteDuration = noteDuration
        _interNoteDelay = interNoteDelay
        _interPhraseDelay = interPhraseDelay
        _preStrikeDelay = preStrikeDelay
        _strikeDuration = strikeDuration
        _interStrikeDelay = interStrikeDelay
    }

    private func durationField(_ label: String, value: Binding<Double>)
        -> some View
    {
        HStack {
            Text(label + " (s):")
            Spacer()
            TextField(
                label,
                value: value,
                format: .number,
            )
            .frame(width: 50)
            .fixedSize()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("Enable Chimes", isOn: $enabled)
            Toggle("Fade Out Music", isOn: $fadeOutMusic)
            Divider()
            HStack {
                Text("Scale Volume")
                Slider(value: $volume, in: 0...1)
            }
            Divider()
            durationField("Fade Duration", value: $fadeOutMusicDuration)
            durationField("Note Length", value: $noteDuration)
            durationField("Note Delay", value: $interNoteDelay)
            durationField("Phrase Delay", value: $interPhraseDelay)
            durationField("Pre Strike Delay", value: $preStrikeDelay)
            durationField("Strike Length", value: $strikeDuration)
            durationField("Strike Delay", value: $interStrikeDelay)
        }
        .padding()
        .frame(width: 220)
    }
}
