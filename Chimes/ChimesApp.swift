import SwiftUI

@main
struct ChimesApp: App {
    @State var active: Bool = true
    
    let player = Player()

    var body : some Scene {
        MenuBarExtra("Chimes", systemImage: "bell\(active ? "" : ".slash")") {
            Toggle("Enable Chimes", isOn: $active)
            Menu("Play Now") {
                Button("First Quarter") {
                    player.playFirstQuarter()
                }
                Button("Half Hour") {
                    player.playHalfHour()
                }
                Button("Third Quarter") {
                    player.playThirdQuarter()
                }
                Menu("Full Hour") {
                    ForEach(1...12, id: \.self) { hour in
                        Button("\(hour)") {
                            player.playHour(hour)
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
