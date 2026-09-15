import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La saisie du retour sur copie.
///
/// Facultative et jamais reclamee (§12) : on la propose une fois le partiel
/// passe, et on ne la redemande pas. Rien n'oblige a la remplir en entier —
/// une note seule suffit, les ratés se cochent si on en a envie.
struct ExamPaperEntry: View {
    let courses: [Course]
    let pages: [Page]
    let examDate: Date
    var onSave: (ExamPaper) -> Void
    var onCancel: () -> Void

    @State private var courseName: String = ""
    @State private var grade: String = ""
    @State private var outOf: String = "20"
    @State private var drafts: [Draft] = []

    private struct Draft: Identifiable {
        let id = UUID()
        var label: String = ""
        var points: String = "1"
        var isCourseQuestion = false
        var pageID: UUID?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("La copie") {
                    Picker("Matière", selection: $courseName) {
                        Text("Sans matière").tag("")
                        ForEach(courses) { Text($0.name).tag($0.name) }
                    }
                    HStack {
                        Text("Note")
                        Spacer()
                        entryField($grade, width: 70)
                        Text("/")
                        entryField($outOf, width: 60)
                    }
                }

                Section {
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Exercice 2 — Dijkstra", text: $draft.label)
                            HStack {
                                Text("Points perdus")
                                Spacer()
                                entryField($draft.points, width: 60)
                            }
                            Toggle("Question de cours", isOn: $draft.isCourseQuestion)
                            Picker("Page", selection: $draft.pageID) {
                                Text("Aucune").tag(UUID?.none)
                                ForEach(pages) { page in
                                    Text(page.title.isEmpty ? "Sans titre" : page.title).tag(UUID?.some(page.id))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }

                    Button("Ajouter un raté") { drafts.append(Draft()) }
                } header: {
                    Text("Ce qui est parti")
                } footer: {
                    Text("Rattacher une page permet à Kurso de dire dans quel état elle était la veille. Sans page, le raté est noté mais rien n'est rapproché.")
                }
            }
            .navigationTitle("Retour sur copie")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }.disabled(Double(normalised(grade)) == nil)
                }
            }
        }
    }

    private func entryField(_ text: Binding<String>, width: CGFloat) -> some View {
        TextField("", text: text)
            .multilineTextAlignment(.trailing)
            .frame(width: width)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
    }

    /// « 14,5 » comme « 14.5 » : on saisit avec la virgule en francais.
    private func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: ".")
    }

    private func save() {
        guard let value = Double(normalised(grade)) else { return }
        let paper = ExamPaper()
        paper.courseName = courseName
        paper.examDate = examDate
        paper.grade = value
        paper.outOf = Double(normalised(outOf)) ?? 20
        paper.misses = drafts.compactMap { draft in
            let label = draft.label.trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { return nil }
            return StoredMiss(
                label: label,
                points: Double(normalised(draft.points)) ?? 0,
                kindRaw: draft.isCourseQuestion ? "courseQuestion" : "exercise",
                pageID: draft.pageID
            )
        }
        onSave(paper)
    }
}
