#if os(iOS)
import SwiftUI

/// L'avancement d'un export.
///
/// Un cahier de cinquante diapos met plusieurs secondes a se redessiner :
/// sans ce retour, l'application paraissait simplement bloquee.
struct ExportProgress: View {
    let value: Double?

    var body: some View {
        if let value {
            ZStack {
                K.ink.opacity(0.35).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    DisplayText("Export en cours", size: 20)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(K.ink.opacity(0.12))
                            Capsule().fill(K.brand)
                                .frame(width: max(6, geo.size.width * value))
                        }
                    }
                    .frame(height: 12)
                    Text("\(Int(value * 100)) %")
                        .font(KFont.mono(11))
                        .foregroundStyle(K.inkSoft)
                }
                .padding(24)
                .frame(width: 320)
                .background(K.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(K.ink, lineWidth: 3))
            }
            .transition(.opacity)
        }
    }
}
#endif
