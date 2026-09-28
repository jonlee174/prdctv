import SwiftData
import SwiftUI

/// Return saves and closes; ⌘Return saves and keeps the panel open for batch entry.
struct QuickAddView: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var added = 0
    @FocusState private var focused: Bool

    private var parsed: QuickAddParser.Result { QuickAddParser().parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image("LogoMark")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(parsed.category.color)
                TextField("write book report 5   ·   w: rewatch a movie 2   ·   #tag !fri", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($focused)
                    .onSubmit { save(keepOpen: false) }
            }
            QuickAddPreview(result: parsed, added: added)
        }
        .padding(16)
        .macFrame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.primary.opacity(0.1)))
        .background {
            // ⌘Return: key equivalents are handled before the text field sees the key.
            Button("") { save(keepOpen: true) }
                .keyboardShortcut(.return, modifiers: .command)
                .hidden()
        }
        .onAppear { focused = true }
    }

    private func save(keepOpen: Bool) {
        let r = parsed
        guard !r.isEmpty else {
            if !keepOpen { onClose() }
            return
        }
        TicketOps.add(title: r.title, category: r.category, points: r.points, status: .upNext,
                      dueDate: r.dueDate, tags: r.tags, context: context)
        added += 1
        text = ""
        if !keepOpen { onClose() }
    }
}

/// Live parse preview chips.
struct QuickAddPreview: View {
    let result: QuickAddParser.Result
    var added = 0

    var body: some View {
        HStack(spacing: 6) {
            chip(result.category.label, systemImage: result.category.symbol, color: result.category.color)
            if RewardSettings.pointsEnabled() {
                chip("\(result.points) pt\(result.points == 1 ? "" : "s")", systemImage: "number", color: .secondary)
            }
            ForEach(result.tags, id: \.self) { TagChip(tag: $0, size: 12) }
            if let due = result.dueDate {
                chip(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                     systemImage: "calendar", color: .secondary)
            }
            Spacer()
            if added > 0 {
                Text("\(added) added").font(.caption).foregroundStyle(.secondary)
            }
            #if os(macOS)
            Text("⏎ save · ⌘⏎ save & next · esc")
                .font(.caption)
                .foregroundStyle(.tertiary)
            #endif
        }
        .opacity(result.isEmpty ? 0.5 : 1)
    }

    private func chip(_ text: String, systemImage: String?, color: Color) -> some View {
        HStack(spacing: 3) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 9)) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: Radius.tiny).fill(color.opacity(0.12)))
    }
}
