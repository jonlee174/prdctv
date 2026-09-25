import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import Vision

/// One-time whiteboard import: photo → on-device OCR → review → tickets in Backlog.
/// Each recognized line goes through the quick-add parser, so writing "w: movie 2" on the board works.
struct WhiteboardImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    struct Row: Identifiable {
        let id = UUID()
        var include = true
        var title: String
        var category: Category
        var points: Int
    }

    @State private var rows: [Row] = []
    @State private var picking = false
    @State private var isRecognizing = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import Whiteboard").font(.title2.bold())
                Spacer()
                Button("Choose Photo…") { picking = true }
            }

            if isRecognizing {
                ProgressView("Reading text…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                ContentUnavailableView {
                    Label("No photo yet", systemImage: "photo")
                } description: {
                    Text("Pick a photo of the whiteboard. Each line becomes a ticket you can review before importing. Lines can use quick-add syntax like “w: movie 2”.")
                } actions: {
                    Button("Choose Photo…") { picking = true }
                }
                .frame(maxHeight: .infinity)
            } else {
                List($rows) { $row in
                    HStack {
                        Toggle("", isOn: $row.include).labelsHidden()
                        TextField("Title", text: $row.title)
                        Picker("", selection: $row.category) {
                            ForEach(Category.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                        Picker("", selection: $row.points) {
                            ForEach(PointScale.values, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 56)
                    }
                    .opacity(row.include ? 1 : 0.45)
                }
            }

            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Import \(selectedCount) Ticket\(selectedCount == 1 ? "" : "s")") { importRows() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedCount == 0)
            }
        }
        .padding(20)
        .frame(width: 560, height: 520)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url): Task { await recognize(url) }
            case .failure(let err): error = err.localizedDescription
            }
        }
    }

    private var selectedCount: Int {
        rows.filter { $0.include && !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private func recognize(_ url: URL) async {
        isRecognizing = true
        defer { isRecognizing = false }
        error = nil

        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }

        do {
            let lines = try await Task.detached { try Self.recognizeLines(in: url) }.value
            let parser = QuickAddParser()
            rows = lines.map { line in
                let r = parser.parse(Self.stripBullet(line))
                return Row(title: r.title, category: r.category, points: r.points)
            }
            .filter { !$0.title.isEmpty }
            if rows.isEmpty { error = "No text found in that photo." }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Runs synchronously; call off the main thread.
    nonisolated private static func recognizeLines(in url: URL) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(url: url).perform([request])
        // Top-to-bottom, then left-to-right (Vision's origin is bottom-left).
        let sorted = (request.results ?? []).sorted {
            abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.02
                ? $0.boundingBox.midY > $1.boundingBox.midY
                : $0.boundingBox.minX < $1.boundingBox.minX
        }
        return sorted.compactMap { $0.topCandidates(1).first?.string }
    }

    /// Drops handwritten bullets and checkboxes ("- ", "• ", "[ ] ", "1. ").
    static func stripBullet(_ line: String) -> String {
        line.replacingOccurrences(of: #"^\s*([-•*·]|\[\s?\]|☐|\d+[.)])\s*"#, with: "", options: .regularExpression)
    }

    private func importRows() {
        for row in rows where row.include {
            let title = row.title.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            TicketOps.add(title: title, category: row.category, points: row.points, status: .backlog, context: context)
        }
        dismiss()
    }
}
