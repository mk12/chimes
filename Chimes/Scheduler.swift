import AppIntents
import AppKit
import Foundation

@MainActor
class Scheduler {
    private let player: Player
    private var currentWorkItem: DispatchWorkItem?

    public var enabled = false {
        didSet {
            if enabled {
                scheduleNextTick(after: Date())
            } else {
                currentWorkItem?.cancel()
                player.stop()
            }
        }
    }

    init(player: Player) {
        self.player = player
        let center = NSWorkspace.shared.notificationCenter
        // Only chime when the screen is awake.
        center.addObserver(
            self,
            selector: #selector(onWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(onSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        // For good measure, also stop chiming when system sleeps.
        center.addObserver(
            self,
            selector: #selector(onSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    @objc private func onWake() {
        if enabled { scheduleNextTick(after: Date()) }
    }

    @objc private func onSleep() {
        if enabled { currentWorkItem?.cancel() }
    }

    private func scheduleNextTick(after: Date) {
        let calendar = Calendar.current
        let quarterMinutes = [0, 15, 30, 45]
        let nextDates = quarterMinutes.map { minute -> Date in
            calendar.nextDate(
                after: after,
                matching: DateComponents(minute: minute, second: 0),
                matchingPolicy: .nextTime
            )!
        }
        scheduleNextTick(for: nextDates.min()!)
    }

    #if DEBUG
        func debugSchedule(chime: Player.Chime) {
            // Round to a whole second, and add 5 seconds for good measure.
            let timestamp = ceil(Date().timeIntervalSinceReferenceDate) + 5
            let start = Date(timeIntervalSinceReferenceDate: timestamp)
            let ahead = player.startAhead(chime: chime)
            let date = start + ahead
            print("scheduling \(chime) for \(start) - \(date)")
            scheduleNextTick(for: date, fixedChime: chime)
        }
    #endif

    private func scheduleNextTick(
        for date: Date,
        fixedChime: Player.Chime? = nil
    ) {
        let chime = fixedChime ?? getChime(date: date)!
        let ahead = player.startAhead(chime: chime)
        let delay = (date - ahead).timeIntervalSinceNow
        // This can happen if scheduling *right* before,
        // without enough extra time for fading out music etc.
        if delay < 0 { return }
        let deadline = DispatchWallTime.now() + delay
        let workItem = DispatchWorkItem(qos: .userInteractive) { [weak self] in
            // Add 30s so getChime will work if we are within 1 minute of the right time.
            let date = Date().addingTimeInterval(ahead + 30)
            self?.tick(date: date, fixedChime: fixedChime)
            self?.scheduleNextTick(after: date)
        }
        currentWorkItem?.cancel()
        currentWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            wallDeadline: deadline,
            execute: workItem,
        )
    }

    private func tick(date: Date, fixedChime: Player.Chime?) {
        let chime = fixedChime ?? getChime(date: date)
        guard let chime else { return }
        guard shouldPlay(chime: chime) else { return }
        Task.detached { [weak self] in
            guard let self else { return }
            try await player.play(chime, scheduled: true)
        }
    }

    private func getChime(date: Date) -> Player.Chime? {
        let minute = Calendar.current.component(.minute, from: date)
        let hour = Calendar.current.component(.hour, from: date)
        return switch minute {
        case 0: .FullHour(hour % 12 == 0 ? 12 : hour % 12)
        case 15: .FirstQuarter
        case 30: .HalfHour
        case 45: .ThirdQuarter
        case 26: .FirstQuarter
        default: nil
        }
    }

    private func shouldPlay(chime: Player.Chime) -> Bool {
        let state = FocusState.shared
        switch chime {
        case .FirstQuarter:
            if !state.firstQuarter { return false }
        case .HalfHour:
            if !state.halfHour { return false }
        case .ThirdQuarter:
            if !state.thirdQuarter { return false }
        case .FullHour:
            if !state.fullHour { return false }
        }
        return true
    }
}
