import SwiftUI

@main
struct ChimesApp: App {
    @State var active: Bool = true

    @ObservedObject private var player : Player
    private let scheduler: Scheduler

    init() {
        let player = Player()
        self.player = player
        scheduler = Scheduler(player: player)
        scheduler.start()
    }

    private func image() -> String {
        if !active {
            return "bell.slash"
        }
        if player.isPlaying {
            return "bell.fill"
        }
        return "bell"
    }

    var body: some Scene {
        MenuBarExtra("Chimes", systemImage: image()) {
            Toggle(
                "Enable Chimes",
                isOn: $active.onChange {
                    if active {
                        scheduler.start()
                    } else {
                        scheduler.stop()
                    }
                }
            )
            Menu("Play Now") {
                Button("First Quarter") {
                    player.play(.FirstQuarter)
                }
                Button("Half Hour") {
                    player.play(.HalfHour)
                }
                Button("Third Quarter") {
                    player.play(.ThirdQuarter)
                }
                Menu("Full Hour") {
                    ForEach(1...12, id: \.self) { hour in
                        Button("\(hour)") {
                            player.play(.FullHour(hour))
                        }
                    }
                }
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

extension Binding {
    @MainActor
    func onChange(_ handler: @escaping () -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler()
            }
        )
    }
}
