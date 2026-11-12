import Foundation
import SwiftUI
import UniformTypeIdentifiers

@main
struct OfflineNotesApp: App {
    var body: some Scene {
        WindowGroup { NotesView() }
    }
}

private struct Note: Identifiable, Codable {
    var id = UUID()
    var title = ""
    var body = ""
}

private struct NotesFile {
    private func location() throws -> URL {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return folder.appendingPathComponent("notes.json")
    }

    func load() throws -> [Note] {
        let url = try location()
        do {
            return try JSONDecoder().decode([Note].self, from: Data(contentsOf: url))
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            return []
        }
    }

    func save(_ notes: [Note]) throws {
        let data = try JSONEncoder().encode(notes)
        try data.write(to: location(), options: .atomic)
    }
}

private struct NotesView: View {
    @State private var notes: [Note] = []
    @State private var draft: Note?
    @State private var canEdit = false
    @State private var errorMessage: String?
    @State private var exportDocument: CSVDocument?
    @State private var exporting = false
    private let file = NotesFile()

    var body: some View {
        NavigationView {
            List {
                if notes.isEmpty {
                    Text(canEdit ? "还没有记录。点右上角的 + 新建。" : "记录暂不可用。")
                        .foregroundColor(.secondary)
                }
                ForEach(notes) { note in
                    Button {
                        draft = note
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title).font(.headline)
                            if !note.body.isEmpty {
                                Text(note.body).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .onDelete { indices in
                    var updated = notes
                    updated.remove(atOffsets: indices)
                    do {
                        try commit(updated)
                    } catch {
                        errorMessage = "保存失败。\(error.localizedDescription)"
                    }
                }
            }
            .navigationTitle("随手记")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("导出 CSV") {
                        exportDocument = CSVDocument(notes: notes)
                        exporting = true
                    }
                    .disabled(notes.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        draft = Note()
                    } label: {
                        Label("新增记录", systemImage: "plus")
                    }
                    .disabled(!canEdit)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: load)
        .sheet(item: $draft) { note in
            NoteEditor(note: note) { edited in
                var updated = notes
                if let index = updated.firstIndex(where: { $0.id == edited.id }) {
                    updated[index] = edited
                } else {
                    updated.insert(edited, at: 0)
                }
                try commit(updated)
            }
        }
        .fileExporter(isPresented: $exporting, document: exportDocument,
                      contentType: .commaSeparatedText, defaultFilename: "随手记") { result in
            if case .failure(let error) = result {
                errorMessage = "导出失败。\(error.localizedDescription)"
            }
        }
        .alert("随手记", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() {
        guard !canEdit else { return }
        do {
            notes = try file.load()
            canEdit = true
        } catch {
            errorMessage = "读取失败。\(error.localizedDescription)"
        }
    }

    private func commit(_ updated: [Note]) throws {
        try file.save(updated)
        notes = updated
    }
}

private struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var note: Note
    @State private var errorMessage: String?
    let save: (Note) throws -> Void

    init(note: Note, save: @escaping (Note) throws -> Void) {
        _note = State(initialValue: note)
        self.save = save
    }

    private var title: String { note.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationView {
            Form {
                TextField("标题", text: $note.title)
                TextEditor(text: $note.body)
                    .frame(minHeight: 180)
                    .accessibilityLabel("正文")
            }
            .navigationTitle("编辑记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        note.title = title
                        do {
                            try save(note)
                            dismiss()
                        } catch {
                            errorMessage = "保存失败。\(error.localizedDescription)"
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("随手记", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]
    private let data: Data

    init(notes: [Note]) {
        let rows = [["标题", "正文"]] + notes.map { [$0.title, $0.body] }
        let csv = rows.map { row in
            row.map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"" + escaped + "\""
            }.joined(separator: ",")
        }.joined(separator: "\r\n")
        data = Data(("\u{FEFF}" + csv + "\r\n").utf8)
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
