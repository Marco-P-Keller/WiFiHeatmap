import SwiftUI
import StoreKit

struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 120
    var body: some View {
        let q = Double(score) / 100
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 12)
            Circle().trim(from: 0, to: max(q, 0.02))
                .stroke(AngularGradient(colors: [Signal.color(0), Signal.color(0.5), Signal.color(1)], center: .center),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Signal.color(q, opacity: 0.5), radius: 10)
            VStack(spacing: -2) {
                Text("\(score)").font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                Text("/ 100").font(.caption2).foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ScanResultView: View {
    @State var session: ScanSession
    let isNew: Bool
    var isCover = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(SessionStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @State private var saved = false
    @State private var shareImage: Image?

    var body: some View {
        Group {
            if isCover { NavigationStack { content } } else { content }
        }
        .environment(\.paywallScope, "result")
        .paywallSheet()
    }

    private var content: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    VStack(spacing: 12) {
                        HeatmapCanvas(session: session)
                        SignalLegend()
                    }
                    .card()
                    stats
                    if !session.pins.isEmpty { pinsCard }
                    tipsCard
                    shareCard
                    if isNew { actionButtons }
                }
                .padding(.horizontal, 18).padding(.bottom, 40)
            }
        }
        .navigationTitle(isNew ? "Your Heatmap" : session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isCover {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
        }
        .task(id: purchases.isPro) { renderShareImage() }
        .onDisappear { if !isNew { store.update(session) } }
    }

    private var header: some View {
        HStack(spacing: 18) {
            ScoreRing(score: session.score)
            VStack(alignment: .leading, spacing: 6) {
                Text(session.grade).font(.title2.weight(.bold))
                TextField("Name this scan", text: $session.name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("\(session.ssid) · \(session.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
        .card()
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("Average", Signal.label(session.averageQ), Signal.color(session.averageQ))
            stat("Weakest", "\(Signal.dBm(session.weakestQ)) dBm", Signal.color(session.weakestQ))
            stat("Dead area", "\(Int((session.deadFraction * 100).rounded()))%", session.deadFraction > 0.1 ? .red : .green)
        }
    }

    private func stat(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
            Text(value).font(.headline).foregroundStyle(tint).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }

    private var pinsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dead zones you marked", systemImage: "mappin.and.ellipse").font(.headline)
            ForEach($session.pins) { $pin in
                HStack {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    TextField("Room name", text: $pin.note)
                    Text("\(Signal.dBm(pin.q)) dBm").font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .card()
    }

    private var tipsCard: some View {
        let tips = Insights.tips(for: session)
        return VStack(alignment: .leading, spacing: 14) {
            Label("How to fix it", systemImage: "wand.and.stars").font(.headline)
            ForEach(Array(tips.enumerated()), id: \.element.id) { idx, tip in
                let locked = idx > 0 && !purchases.isPro
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: tip.icon).font(.title3).foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tip.title).font(.subheadline.weight(.semibold))
                        Text(tip.detail).font(.footnote).foregroundStyle(Theme.secondary)
                    }
                }
                .blur(radius: locked ? 6 : 0)
                .overlay(alignment: .center) { if locked { Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.8)) } }
                .accessibilityHidden(locked)
            }
            if !purchases.isPro {
                Button("Unlock all personalised tips") { _ = purchases.requirePro(.tips, scope: "result") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card()
    }

    private var shareCard: some View {
        VStack(spacing: 12) {
            if let img = shareImage {
                ShareLink(item: img, preview: SharePreview("My Wi-Fi heatmap", image: img)) {
                    Label("Share heatmap", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.violet))
            }
            if !purchases.isPro {
                Button("Remove watermark with Pro") { _ = purchases.requirePro(.export, scope: "result") }
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(saved ? "Saved ✓" : "Save to My Rooms") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(saved)
            Button("Discard", role: .destructive) { dismiss() }.font(.subheadline)
        }
    }

    private func save() {
        if store.sessions.count >= Config.freeSavedScanLimit && !purchases.requirePro(.saveLimit, scope: "result") { return }
        store.add(session)
        saved = true
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if store.sessions.count == 1 { requestReview() }
        }
    }

    @MainActor private func renderShareImage() {
        let card = ShareCardView(session: session, watermark: !purchases.isPro)
        let r = ImageRenderer(content: card)
        r.scale = 2
        if let ui = r.uiImage { shareImage = Image(uiImage: ui) }
    }
}

/// 1080×1350 (4:5) social card – designed to be screenshot-worthy and carry the app's name.
struct ShareCardView: View {
    let session: ScanSession
    let watermark: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.name).font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Wi-Fi coverage map").font(.system(size: 17)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    ScoreRing(score: session.score, size: 96)
                }
                HeatmapCanvas(session: session).frame(maxWidth: .infinity)
                SignalLegend()
                HStack(spacing: 24) {
                    pill("Dead area", "\(Int((session.deadFraction * 100).rounded()))%")
                    pill("Weakest", "\(Signal.dBm(session.weakestQ)) dBm")
                    pill("Grade", session.grade)
                }
                Spacer(minLength: 0)
                if watermark {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                        Text("Made with WiFi Heatmap AR").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
            .padding(34)
        }
        .frame(width: 540, height: 675)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func pill(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(t).font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}
