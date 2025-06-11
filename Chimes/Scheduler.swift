import AppIntents
import AppKit
import Foundation
import os

@MainActor
class Scheduler {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Scheduler.self)
    )
    private static let formatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = .current
        return formatter
    }()

    private let player: Player
    private let timer: DispatchSourceTimer

    public var enabled = false {
        didSet {
            if enabled {
                start()
            } else {
                stop()
            }
        }
    }

    init(player: Player) {
        self.player = player
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        timer.activate()
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

    private func start() {
        scheduleNextTick(after: Date())
    }

    private func stop() {
        Self.logger.debug("stopping")
        timer.suspend()
        player.stop()
    }

    @objc private func onWake() { if enabled { start() } }
    @objc private func onSleep() { if enabled { stop() } }

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
            scheduleNextTick(for: date, fixedChime: chime)
        }
    #endif

    private func scheduleNextTick(
        for date: Date,
        fixedChime: Player.Chime? = nil
    ) {
        let chime = fixedChime ?? getChime(date: date)!
        let ahead = player.startAhead(chime: chime)
        let dateStr = Self.formatter.string(from: date)
        let aheadStr = String(format: "%.3f", ahead)
        Self.logger.debug("scheduling \(dateStr) (minus \(aheadStr)s)")
        let target = date - ahead
        let delay = target.timeIntervalSinceNow
        // This can happen if scheduling *right* before,
        // without enough extra time for fading out music etc.
        if delay < 0 { return }
        let deadline = DispatchWallTime.now() + delay
        timer.setEventHandler(qos: .userInteractive) { [weak self] in
            let error = Date().timeIntervalSince(target)
            if abs(error) > 20 {
                Self.logger.error("schedule for \(dateStr) off by \(error)s")
                return
            }
            self?.tick(chime: chime)
            self?.scheduleNextTick(after: date)
        }
        timer.schedule(
            wallDeadline: deadline,
            repeating: .never,
            leeway: .milliseconds(100)
        )
    }

    private func tick(chime: Player.Chime) {
        guard shouldPlay(chime: chime) else { return }
        Task.detached { [weak self] in
            guard let self else { return }
            try await player.play(chime, scheduled: true)
        }
    }

    private func getChime(date: Date) -> Player.Chime? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
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
