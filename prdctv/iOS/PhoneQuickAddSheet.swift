import SwiftData
import SwiftUI

/// Quick add on iPhone. The keyboard's return key saves and stays open for batch entry;
/// "Add" saves and closes.
struct PhoneQuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var added = 0
    @FocusState private var focused: Bool

    private var parsed: QuickAddParser.Result { QuickAddParser().parse(text) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("write book report 5 · w: movie 2", text: $text)
                    .font(.title3)
                    .focused($focused)
                    .submitLabel(.next)
                    .onSubmit {
                        save()
                        focused = true
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Radius.small).fill(Color(uiColor: .secondarySystemBackground)))

                ScrollView(.horizontal, showsIndicators: false) {
                    QuickAddPreview(result: parsed, added: added)
                }

                Text("Start with **n:**, **w:** or **f:**. End with 1, 2, 3, 5 or 8 for points. Add **#tag** or a due date like **!fri**, **!tmr** or **!3d**.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(added > 0 ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                        dismiss()
                    }
                    .disabled(parsed.isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let r = parsed
        guard !r.isEmpty else { return }
        TicketOps.add(title: r.title, category: r.category, points: r.points, status: .upNext,
                      dueDate: r.dueDate, tags: r.tags, context: context)
        added += 1
        text = ""
    }
}
