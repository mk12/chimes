import AppIntents
import os

class FocusState {
    static let shared = FocusState()

    var firstQuarter = true
    var halfHour = true
    var thirdQuarter = true
    var fullHour = true
}

struct FocusFilter: SetFocusFilterIntent {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Scheduler.self)
    )

    static var title: LocalizedStringResource = "Filter Chimes"
    static var description: LocalizedStringResource =
        "Filter chimes in this focus mode."

    @Parameter(title: "First Quarter", default: true)
    var firstQuarter: Bool
    @Parameter(title: "Half Hour", default: true)
    var halfHour: Bool
    @Parameter(title: "Third Quarter", default: true)
    var thirdQuarter: Bool
    @Parameter(title: "Full Hour", default: true)
    var fullHour: Bool

    private func subtitle() -> LocalizedStringResource {
        var parts: [String] = []
        if firstQuarter { parts.append("First Quarter") }
        if halfHour { parts.append("Half Hour") }
        if thirdQuarter { parts.append("Third Quarter") }
        if fullHour { parts.append("Full Hour") }
        if parts.isEmpty {
            parts.append("No Chimes")
        }
        let result = parts.joined(separator: ", ")
        return "\(result)"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: FocusFilter.title, subtitle: subtitle())
    }

    func perform() async throws -> some IntentResult {
        Self.logger.log("performing focus filter")
        let state = FocusState.shared
        state.firstQuarter = firstQuarter
        state.halfHour = halfHour
        state.thirdQuarter = thirdQuarter
        state.fullHour = fullHour
        return .result()
    }
}
