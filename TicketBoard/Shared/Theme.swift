import SwiftUI

extension Category {
    var color: Color {
        switch self {
        case .need: Color(red: 0.22, green: 0.47, blue: 0.93)
        case .want: Color(red: 0.93, green: 0.55, blue: 0.13)
        case .fun: Color(red: 0.80, green: 0.27, blue: 0.62)
        }
    }
}

/// Ticket-stub outline: rounded card with semicircle notches at the perforation line.
struct TicketShape: Shape {
    var stubWidth: CGFloat = 40
    var notch: CGFloat = 5
    var corner: CGFloat = 9

    func path(in r: CGRect) -> Path {
        let x = r.maxX - stubWidth
        var p = Path()
        p.move(to: CGPoint(x: r.minX + corner, y: r.minY))
        p.addLine(to: CGPoint(x: x - notch, y: r.minY))
        p.addArc(center: CGPoint(x: x, y: r.minY), radius: notch,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: corner)
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: corner)
        p.addLine(to: CGPoint(x: x + notch, y: r.maxY))
        p.addArc(center: CGPoint(x: x, y: r.maxY), radius: notch,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: corner)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: corner)
        p.closeSubpath()
        return p
    }
}

/// Progress ring used by the reward meter in both the app and the widget.
struct RewardRing: View {
    var kind: Category
    var engine: RewardEngine
    var lineWidth: CGFloat = 5
    var showsLabel = true

    var body: some View {
        ZStack {
            Circle().stroke(kind.color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: engine.fraction(kind))
                .stroke(kind.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                Text("\(engine.progress(kind))/\(engine.settings.ratio(for: kind))")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .padding(lineWidth)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(engine.progressLabel(kind))
    }
}
