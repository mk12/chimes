import SwiftUI

struct SettingsView<InstrumentPicker: View>: View {
    @Binding private var enabled: Bool
    @Binding private var volume: Double
    @Binding private var fadeMusic: Bool

    @Binding private var noteDuration: Double
    @Binding private var noteInterval: Double
    @Binding private var phraseInterval: Double
    @Binding private var preStrikeDelay: Double
    @Binding private var strikeDuration: Double
    @Binding private var strikeInterval: Double

    @Binding private var timingAdjustment: Double
    @Binding private var fadeMusicDuration: Double
    @Binding private var fadeMusicSlack: Double

    private let scheduler: Scheduler
    private let instrumentPicker: InstrumentPicker

    init(
        scheduler: Scheduler,
        instrumentPicker: InstrumentPicker,
        enabled: Binding<Bool>,
        volume: Binding<Double>,
        fadeMusic: Binding<Bool>,
        noteDuration: Binding<Double>,
        noteInterval: Binding<Double>,
        phraseInterval: Binding<Double>,
        preStrikeDelay: Binding<Double>,
        strikeDuration: Binding<Double>,
        strikeInterval: Binding<Double>,
        timingAdjustment: Binding<Double>,
        fadeMusicDuration: Binding<Double>,
        fadeMusicSlack: Binding<Double>,
    ) {
        self.scheduler = scheduler
        self.instrumentPicker = instrumentPicker
        _enabled = enabled
        _volume = volume
        _fadeMusic = fadeMusic
        _noteDuration = noteDuration
        _noteInterval = noteInterval
        _phraseInterval = phraseInterval
        _preStrikeDelay = preStrikeDelay
        _strikeDuration = strikeDuration
        _strikeInterval = strikeInterval
        _timingAdjustment = timingAdjustment
        _fadeMusicDuration = fadeMusicDuration
        _fadeMusicSlack = fadeMusicSlack
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
            Toggle("Fade Out Media", isOn: $fadeMusic)
            Divider()
            instrumentPicker
            Divider()
            HStack {
                Text("Scale Volume")
                Slider(value: $volume, in: 0...1)
            }
            Divider()
            durationField("Note Duration", value: $noteDuration)
            durationField("Note Interval", value: $noteInterval)
            durationField("Phrase Interval", value: $phraseInterval)
            durationField("First Strike Delay", value: $preStrikeDelay)
            durationField("Strike Duration", value: $strikeDuration)
            durationField("Strike Interval", value: $strikeInterval)
            Divider()
            durationField("Timing Adjustment", value: $timingAdjustment)
            durationField("Fade Duration", value: $fadeMusicDuration)
            durationField("Fade Slack", value: $fadeMusicSlack)
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
