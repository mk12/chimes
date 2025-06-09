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
    @objc private func onSleep() { if enabled { currentWorkItem?.cancel() } }

    private func scheduleNextTick(after: Date) {
        let calendar = Calendar.current
        let quarterMinutes = [0, 15, 30, 45]
        let nextDates = quarterMinutes.map { minute -> Date in
            calendar.nextDate(
                after: after,
                matching: DateComponents(minute: minute),
                matchingPolicy: .nextTime
            )!
        }
        let next = nextDates.min()!
        let chime = getChime(date: next)!
        let ahead = player.startAhead(chime: chime)
        let delay = (next - ahead).timeIntervalSinceNow
        // This can happen if scheduling *right* before,
        // without enough extra time for fading out music etc.
        if delay < 0 { return }

        let workItem = DispatchWorkItem { [weak self] in
            let date = Date().addingTimeInterval(ahead)
            self?.tick(date: date)
            self?.scheduleNextTick(after: date)
        }
        currentWorkItem?.cancel()
        currentWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    private func tick(date: Date) {
        let chime = getChime(date: date)
        guard let chime else { return }
        guard shouldPlay(chime: chime) else { return }
        Task.detached { [weak self] in
            guard let self else { return }
            try await player.play(chime)
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
