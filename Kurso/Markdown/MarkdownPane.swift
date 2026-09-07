import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Le volet markdown (§11, etape 1).
///
/// Il coexiste avec le dessin plutot que de s'y substituer : une page peut
/// porter les deux, et c'est cette cohabitation qui permettra plus tard
/// d'apprendre les paires d'abreviations (§4, `source = .learnedFromMac`).
struct MarkdownPane: View {
    @Bindable var page: Page
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var isLoaded = false

    /// L'enregistrement est differe : ecrire en base a chaque frappe ferait
    /// tourner CloudKit en continu pour rien.
    private let saveDelay = Duration.seconds(1)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(12)
                .onChange(of: text) { _, _ in scheduleSave() }

            Divider()
            footer
        }
        .task {
            // Une seule fois : recharger a chaque reapparition ecraserait une
            // frappe en cours par l'etat en base.
            guard !isLoaded else { return }
            text = page.markdown
            isLoaded = true
        }
        .onDisappear {
            saveTask?.cancel()
            save()
        }
    }

    private var footer: some View {
        HStack {
            Text("^[\(lineCount) ligne](inflect: true)")
            Spacer()
            if page.titleWasEdited {
                Label("Titre fige", systemImage: "lock")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var lineCount: Int {
        text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        page.markdown = text

        // §4 : la premiere ligne fait le titre, sauf si l'etudiant l'a edite —
        // dans ce cas on n'y retouche plus jamais.
        if !page.titleWasEdited, let derived = PageTitle.derive(from: text) {
            page.title = derived
        }

        try? context.save()
    }
}
