import SwiftUI

/// Per device setting for confetti when a ticket is done.
enum Confetti {
    static let enabledKey = "confettiEnabled"
}

/// Confetti falling from the top, started again each time `trigger` changes. Never takes taps.
struct ConfettiOverlay: View {
    let trigger: Int
    @State private var start: Date?
    @State private var pieces: [Piece] = []

    private static let duration = 4.0
    /// Pinks and the prdctv greens.
    private static let colors: [Color] = [
        Color(hex: "#E0569B")!, Color(hex: "#C73E83")!, Color(hex: "#D6408A")!, Color(hex: "#F5A9CB")!,
        Color(hex: "#8ED973")!, Color(hex: "#55A838")!, Color(hex: "#458F32")!, Color(hex: "#C4EDB0")!,
    ]

    struct Piece {
        let x: Double, drift: Double, fall: Double, delay: Double
        let spin: Double, sway: Double, size: CGSize, color: Color

        static func random() -> Piece {
            Piece(x: .random(in: 0...1), drift: .random(in: -40...40), fall: .random(in: 120...260),
                  delay: .random(in: 0...0.6), spin: .random(in: -8...8), sway: .random(in: 8...26),
                  size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
                  color: colors.randomElement()!)
        }
    }

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    // Falls with gravity, sways side to side, tumbles, and fades in the last second.
                    let x = piece.x * size.width + piece.drift * t + sin(t * 3 + piece.spin) * piece.sway
                    let y = -20 + piece.fall * t + 0.5 * 260 * t * t
                    guard y < size.height + 30 else { continue }
                    var copy = context
                    copy.opacity = min(1, max(0, Self.duration - elapsed))
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(piece.spin * t))
                    let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                      width: piece.size.width, height: piece.size.height * abs(cos(t * 4 + piece.spin)))
                    copy.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            pieces = (0..<160).map { _ in Piece.random() }
            let started = Date()
            start = started
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration) {
                if start == started { start = nil }
            }
        }
    }
}

/// Drops confetti over the view whenever a ticket is done, unless turned off in Settings.
private struct CelebratesCompletions: ViewModifier {
    @AppStorage(Confetti.enabledKey) private var enabled = true
    @State private var trigger = 0

    func body(content: Content) -> some View {
        content
            .overlay { ConfettiOverlay(trigger: trigger).ignoresSafeArea() }
            #if os(iOS)
            .sensoryFeedback(.success, trigger: trigger)
            #endif
            .onReceive(NotificationCenter.default.publisher(for: .ticketCompleted)) { _ in
                if enabled { trigger += 1 }
            }
    }
}

extension View {
    func celebratesCompletions() -> some View {
        modifier(CelebratesCompletions())
    }
}
