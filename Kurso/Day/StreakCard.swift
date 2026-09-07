import SwiftUI
import SwiftData
import KursoCore
import KursoModels

/// La carte de série, telle que le prototype la dispose : la flamme, le compte
/// en jours, la bande de la semaine, puis les gels et les gommes.
struct StreakCard: View {
    let streak: Int
    let record: Int
    let freezes: Int
    let gommes: Int
    let week: [DayMark]
    let gribouMood: GribouMood?
    let gribouLine: String

    struct DayMark: Identifiable {
        let id = UUID()
        let label: String
        let done: Bool
        let isToday: Bool
        let isFuture: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                AnimatedFlame().frame(width: 52, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(streak)").font(KFont.display(40)).foregroundStyle(K.ink)
                        Text("jours").font(KFont.body(14, weight: .extraBold)).foregroundStyle(K.inkSoft)
                    }
                    Text("record : \(record) jour\(record > 1 ? "s" : "")")
                        .font(KFont.body(12, weight: .extraBold))
                        .foregroundStyle(K.flame)
                }
            }

            weekStrip.padding(.top, 14)
            resources.padding(.top, 12)

            Text("Une gomme se regagne toutes les 4 h. Un gel rattrape une journée manquée.")
                .font(KFont.body(10.5, weight: .bold))
                .foregroundStyle(K.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            if let gribouMood {
                HStack(alignment: .center, spacing: 12) {
                    GribouView(mood: gribouMood, size: 74)
                    Text(gribouLine)
                        .font(KFont.body(12.5, weight: .extraBold))
                        .foregroundStyle(K.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(fill: K.paperAlt, radius: 26)
    }

    /// Les sept jours de la semaine. Un jour à venir est en pointillés : on ne
    /// reproche pas à quelqu'un de ne pas avoir encore travaillé demain.
    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(week) { day in
                VStack(spacing: 5) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(day.done ? K.flame : (day.isToday ? Color(token: "#FFF1E8") : K.paperAlt))
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(K.ink, style: StrokeStyle(
                                lineWidth: 2.5,
                                dash: day.isFuture ? [5, 4] : []
                            ))
                        if day.done {
                            Checkmark()
                                .stroke(K.paperAlt, style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
                                .frame(width: 13, height: 13)
                        } else if day.isToday {
                            Circle().fill(K.flame).frame(width: 7, height: 7)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)

                    Text(day.label)
                        .font(KFont.body(9, weight: .extraBold))
                        .foregroundStyle(day.isToday ? K.ink : K.inkSoft)
                }
            }
        }
    }

    private var resources: some View {
        HStack(spacing: 8) {
            resourceBox(count: "\(freezes) en réserve", label: "gels", tint: Color(token: "#EAF6FF")) {
                SnowflakeShape()
                    .stroke(K.ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 12, height: 12)
            }
            resourceBox(count: "\(gommes) / \(GameValues.maxGommes)", label: "gommes", tint: Color(token: "#FFF1F3")) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(K.eraser)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(K.ink, lineWidth: 2))
                    .frame(width: 10, height: 13)
            }
        }
    }

    private func resourceBox<Icon: View>(
        count: String, label: String, tint: Color, @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(K.paperAlt)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(K.ink, lineWidth: 2.5))
                .frame(width: 22, height: 22)
                .overlay { icon() }
            VStack(alignment: .leading, spacing: 1) {
                Text(count).font(KFont.display(15)).foregroundStyle(K.ink)
                Text(label.uppercased())
                    .font(KFont.body(8.5, weight: .extraBold))
                    .tracking(0.7)
                    .foregroundStyle(K.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(K.ink, lineWidth: 2.5))
    }
}

/// La flamme de la série : deux rythmes qui ne se synchronisent jamais, c'est
/// ce qui fait un feu plutôt qu'un clignotant.
struct AnimatedFlame: View {
    @State private var outer = false
    @State private var inner = false

    var body: some View {
        ZStack {
            FlameShape()
                .fill(K.flame)
                .overlay(FlameShape().stroke(K.ink, lineWidth: 3))
                .scaleEffect(x: outer ? 1.07 : 0.96, y: outer ? 0.95 : 1.06, anchor: .bottom)
                .rotationEffect(.degrees(outer ? 2.5 : -2.5), anchor: .bottom)

            FlameShape()
                .fill(K.reward)
                .frame(width: 24, height: 30)
                .offset(y: 8)
                .scaleEffect(x: inner ? 0.86 : 1.1, y: inner ? 1.12 : 0.92, anchor: .bottom)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: DesignTokens.Motion.flameLoopSeconds).repeatForever(autoreverses: true)) {
                outer = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                inner = true
            }
        }
    }
}

/// Le gel, dessiné — trois traits croisés.
struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for angle in stride(from: 0.0, to: 180.0, by: 60.0) {
            let a = angle * .pi / 180
            p.move(to: CGPoint(x: c.x - cos(a) * r, y: c.y - sin(a) * r))
            p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
        }
        return p
    }
}
