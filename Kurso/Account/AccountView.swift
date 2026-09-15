import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// Le compte et les préférences.
///
/// Un seul écran, parce qu'il n'y a qu'une poignée de choses à régler : Kurso
/// n'a pas de préférences pour compenser des décisions non prises. Tout ce qui
/// pouvait être tranché une fois pour toutes l'a été dans la direction
/// artistique et dans le §12.
struct AccountView: View {
    var onClose: () -> Void
    var onOpenLeague: () -> Void = {}

    @Environment(\.modelContext) private var context
    @State private var auth = AuthClient.shared
    @State private var player: PlayerState?
    @State private var name = ""
    #if os(iOS)
    @State private var backupFile: ExportedFile?
    @State private var isPickingBackup = false
    @State private var pendingRestore: Backup.Archive?
    #endif
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                identityCard
                preferencesCard
                dataCard
                aboutCard
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.paper)
        .task { load() }
        #if os(iOS)
        .sheet(item: $backupFile) { ShareSheet(url: $0.url) }
        .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [.json, .data]) { result in
            readBackup(result)
        }
        .alert("Restaurer cette sauvegarde ?", isPresented: Binding(
            get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("Remplacer tout", role: .destructive) {
                if let archive = pendingRestore { applyRestore(archive) }
            }
            Button("Annuler", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("Elle contient \(pendingRestore?.summary ?? ""). Tout ce qui est actuellement dans Kurso sera remplacé.")
        }
        #endif
        .alert("Compte", isPresented: Binding(
            get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                ChevronGlyph()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 12, height: 12)
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(K.ink, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
            DisplayText("Ton compte", size: 30)
            Spacer(minLength: 0)
        }
    }

    // MARK: Identité

    private var identityCard: some View {
        card("TOI") {
            HStack(spacing: 14) {
                Circle()
                    .fill(K.reward)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(K.ink, lineWidth: 2.5))
                    .overlay(
                        Text(String(name.first ?? "K").uppercased())
                            .font(KFont.display(21))
                            .foregroundStyle(K.ink))
                VStack(alignment: .leading, spacing: 3) {
                    TextField("Ton prénom", text: $name)
                        .textFieldStyle(.plain)
                        .font(KFont.display(19))
                        .foregroundStyle(K.ink)
                        .onSubmit(saveName)
                    Text(auth.session?.email ?? "Pas connecté")
                        .font(KFont.mono(11))
                        .foregroundStyle(K.inkSoft)
                }
                Spacer(minLength: 0)
            }

            Text("Le prénom sert à te dire bonjour en haut de l'écran. Il ne sort pas d'ici.")
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)

            row("Ta ligue et tes amis") { onOpenLeague() }

            if auth.isSignedIn {
                row("Se déconnecter", destructive: true) {
                    auth.signOut()
                    message = "Déconnecté. Tes cahiers restent sur cet iPad."
                }
            }
        }
    }

    // MARK: Préférences

    private var preferencesCard: some View {
        card("RAPPELS") {
            Text("Kurso peut te prévenir d'un partiel qui approche ou d'un devoir à rendre. Deux par jour au maximum, rien le week-end sans échéance.")
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
            row("Ouvrir les réglages du système") {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
        }
    }

    // MARK: Données

    private var dataCard: some View {
        card("TES CAHIERS") {
            Text("Tout vit sur cet appareil. Une sauvegarde est le seul moyen de les retrouver si tu perds l'iPad — garde le fichier ailleurs.")
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
                .fixedSize(horizontal: false, vertical: true)
            #if os(iOS)
            row("Sauvegarder mes cahiers") {
                do { backupFile = ExportedFile(url: try BackupStore.write(context)) }
                catch { message = "La sauvegarde n'a pas pu être écrite." }
            }
            row("Restaurer une sauvegarde…") { isPickingBackup = true }
            #endif
        }
    }

    private var aboutCard: some View {
        card("À PROPOS") {
            keyValue("Version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            keyValue("Pages", "\((try? context.fetchCount(FetchDescriptor<Page>())) ?? 0)")
            keyValue("Cartes", "\((try? context.fetchCount(FetchDescriptor<Card>())) ?? 0)")
            Text("Aucune donnée de cours ne quitte cet appareil : ni page, ni carte, ni audio, ni PDF.")
                .font(KFont.body(12, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Briques

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(KFont.mono(10))
                .tracking(1.2)
                .foregroundStyle(K.inkSoft)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.paperAlt, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(K.ink, lineWidth: 2.5))
    }

    private func row(_ label: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(KFont.body(13.5, weight: .extraBold))
                    .foregroundStyle(destructive ? K.alertBg : K.ink)
                Spacer(minLength: 8)
                ChevronGlyph(pointsRight: true)
                    .stroke(destructive ? K.alertBg : K.inkSoft,
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 9)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(destructive ? K.alertBg.opacity(0.08) : K.paper,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(destructive ? K.alertBg.opacity(0.4) : K.ink.opacity(0.14), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(KFont.body(12.5, weight: .bold))
                .foregroundStyle(K.inkBody)
            Spacer(minLength: 8)
            Text(value)
                .font(KFont.mono(12))
                .foregroundStyle(K.ink)
        }
    }

    // MARK: Actions

    private func load() {
        let state = PlayerStore.current(context)
        player = state
        name = state.displayName
    }

    private func saveName() {
        guard let player else { return }
        player.displayName = name.trimmingCharacters(in: .whitespaces)
        try? context.save()
    }

    #if os(iOS)
    private func readBackup(_ result: Result<URL, Error>) {
        isPickingBackup = false
        guard case .success(let url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        do { pendingRestore = try Backup.decode(try Data(contentsOf: url)) }
        catch Backup.Failure.tooRecent(let version) {
            message = "Cette sauvegarde vient d'une version plus récente de Kurso (format \(version))."
        } catch { message = "Ce fichier n'est pas une sauvegarde Kurso lisible." }
    }

    private func applyRestore(_ archive: Backup.Archive) {
        pendingRestore = nil
        do {
            try BackupStore.restore(archive, context: context)
            load()
            message = "Restauré. \(archive.summary)."
        } catch { message = "La restauration a échoué. Rien n'a été remplacé." }
    }
    #endif
}
