import SwiftUI

/// Persistent header: Want and Fun progress rings plus available-reward counts.
/// Completing need points floats a "+N" into the meter; earning a reward pulses it.
struct RewardMeterView: View {
    let engine: RewardEngine
    /// Hidden on iPhone, where width is tight.
    var showsTotal = true
    let onRedeem: (Category) -> Void

    @State private var gain: Int?
    @State private var gainID = 0
    @State private var celebrate: Category?

    var body: some View {
        HStack(spacing: 28) {
            meter(.want)
            meter(.fun)
            Spacer(minLength: 0)
            if showsTotal { total }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .animation(.spring(duration: 0.5), value: engine)
        .onChange(of: engine.needPointsDone) { old, new in
            guard new > old else { return }
            gainID += 1
            withAnimation(.spring(duration: 0.35)) { gain = new - old }
            let id = gainID
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                guard id == gainID else { return }
                withAnimation(.easeIn(duration: 0.45)) { gain = nil }
            }
        }
        .onChange(of: engine.earnedWant) { old, new in if new > old { pulse(.want) } }
        .onChange(of: engine.earnedFun) { old, new in if new > old { pulse(.fun) } }
    }

    private var total: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(engine.needPointsDone)")
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: Double(engine.needPointsDone)))
            Text("need points done").font(.caption).foregroundStyle(.secondary)
        }
        .overlay(alignment: .topLeading) {
            if let gain {
                Text("+\(gain)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Category.need.color)
                    .id(gainID)
                    .transition(.asymmetric(
                        insertion: .offset(y: 24).combined(with: .opacity),
                        removal: .offset(x: -60, y: -6).combined(with: .opacity).combined(with: .scale(scale: 0.5))
                    ))
                    .offset(x: -36)
            }
        }
    }

    private func meter(_ kind: Category) -> some View {
        let available = engine.available(kind)
        return HStack(spacing: 10) {
            RewardRing(kind: kind, engine: engine, lineWidth: 5)
                .frame(width: 46, height: 46)
                .scaleEffect(celebrate == kind ? 1.18 : 1)
                .shadow(color: celebrate == kind ? kind.color.opacity(0.7) : .clear, radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.label).font(.subheadline.weight(.semibold))
                Button {
                    onRedeem(kind)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: available > 0 ? "gift.fill" : "gift")
                            .symbolEffect(.bounce, value: engine.earned(kind))
                        Text("\(available) available")
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(available)))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(available > 0 ? kind.color : (available < 0 ? .red : .secondary))
                }
                .buttonStyle(.plain)
                .help(available > 0 ? "Redeem a \(kind.label) reward" : engine.progressLabel(kind))
            }
        }
    }

    private func pulse(_ kind: Category) {
        withAnimation(.spring(duration: 0.3, bounce: 0.5)) { celebrate = kind }
        Task {
            try? await Task.sleep(for: .seconds(0.7))
            withAnimation(.spring(duration: 0.4)) { if celebrate == kind { celebrate = nil } }
        }
    }
}
