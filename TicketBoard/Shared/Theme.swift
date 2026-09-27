import SwiftUI

extension Category {
    /// Current color: the user's choice (Settings → Categories) or the default.
    var color: Color {
        Color(hex: AppGroup.defaults.string(forKey: colorKey) ?? "") ?? Color(hex: defaultColorHex)!
    }

    var defaultColorHex: String {
        switch self {
        // Shades of the logo green; the shapes (circle / diamond / star) keep them apart.
        case .need: "#458F32"
        case .want: "#709929"
        case .fun: "#2A8463"
        }
    }
}

/// Corner radii, kept tight so surfaces read as crisp rather than bubbly.
enum Radius {
    /// Badges, chips, thin bars.
    static let tiny: CGFloat = 2
    /// Cards, calendar cells, inputs, buttons.
    static let small: CGFloat = 4
    /// Columns, panels, tiles.
    static let medium: CGFloat = 6
}

/// Ticket-stub outline: rounded card with semicircle notches at the perforation line.
struct TicketShape: Shape {
    var stubWidth: CGFloat = 40
    var notch: CGFloat = 4
    var corner: CGFloat = Radius.small

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

extension Color {
    /// Neutral card surface that contrasts with the column background on both platforms.
    static var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

extension View {
    /// Fixed sheet sizes only make sense on the Mac; iOS sheets size themselves.
    func macFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        #if os(macOS)
        frame(width: width, height: height)
        #else
        self
        #endif
    }
}

/// The full prdctv logo (mark + Bauhaus 93 wordmark, as vector outlines), in the current text color.
struct AppLogo: View {
    var height: CGFloat = 20

    var body: some View {
        Image("LogoFull")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("prdctv")
    }
}
