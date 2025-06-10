import SwiftUI

struct SettingsView<InstrumentPicker: View>: View {
    @Binding private var enabled: Bool
    @Binding private var volume: Double
    @Binding private var fadeMusic: Bool

    @Binding private var noteDuration: Double
    @Binding private var interNoteDelay: Double
    @Binding private var interPhraseDelay: Double
    @Binding private var preStrikeDelay: Double
    @Binding private var strikeDuration: Double
    @Binding private var interStrikeDelay: Double

    @Binding private var fadeMusicDuration: Double
    @Binding private var timingAdjustment: Double
    @Binding private var fadeMusicAdjustment: Double

    private let scheduler: Scheduler
    private let instrumentPicker: InstrumentPicker

    init(
        scheduler: Scheduler,
        instrumentPicker: InstrumentPicker,
        enabled: Binding<Bool>,
        volume: Binding<Double>,
        fadeMusic: Binding<Bool>,
        noteDuration: Binding<Double>,
        interNoteDelay: Binding<Double>,
        interPhraseDelay: Binding<Double>,
        preStrikeDelay: Binding<Double>,
        strikeDuration: Binding<Double>,
        interStrikeDelay: Binding<Double>,
        fadeMusicDuration: Binding<Double>,
        timingAdjustment: Binding<Double>,
        fadeMusicAdjustment: Binding<Double>,
    ) {
        self.scheduler = scheduler
        self.instrumentPicker = instrumentPicker
        _enabled = enabled
        _volume = volume
        _fadeMusic = fadeMusic
        _noteDuration = noteDuration
        _interNoteDelay = interNoteDelay
        _interPhraseDelay = interPhraseDelay
        _preStrikeDelay = preStrikeDelay
        _strikeDuration = strikeDuration
        _interStrikeDelay = interStrikeDelay
        _fadeMusicDuration = fadeMusicDuration
        _timingAdjustment = timingAdjustment
        _fadeMusicAdjustment = fadeMusicAdjustment
    }

    private func durationField(_ label: String, value: Binding<Double>)
        -> some View
    {
        HStack {
            Text(label + ":")
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
            Toggle("Fade Out Music", isOn: $fadeMusic)
            Divider()
            instrumentPicker
            Divider()
            HStack {
                Text("Scale Volume")
                Slider(value: $volume, in: 0...1)
            }
            Divider()
            durationField("Note Length", value: $noteDuration)
            durationField("Note Delay", value: $interNoteDelay)
            durationField("Phrase Delay", value: $interPhraseDelay)
            durationField("Pre Strike Delay", value: $preStrikeDelay)
            durationField("Strike Length", value: $strikeDuration)
            durationField("Strike Delay", value: $interStrikeDelay)
            Divider()
            durationField("Timing Adjustment", value: $timingAdjustment)
            durationField("Fade Duration", value: $fadeMusicDuration)
            durationField("Fade Adjustment", value: $fadeMusicAdjustment)
            #if DEBUG
                Divider()
                HStack {
                    Button(
                        "Debug Qr",
                        action: {
                            scheduler.debugSchedule(chime: .FirstQuarter)
                        }
                    )
                    Button(
                        "Debug Hr",
                        action: {
                            scheduler.debugSchedule(chime: .FullHour(1))
                        }
                    )
                }.frame(maxWidth: .infinity)
            #endif
        }
        .padding()
        .frame(width: 210)
    }
}
