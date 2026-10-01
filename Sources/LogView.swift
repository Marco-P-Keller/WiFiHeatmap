import SwiftUI

struct LogView: View {
    enum Segment: String, CaseIterable { case rooms = "Scans", spots = "Dead Zones" }

    @Environment(SessionStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @State private var segment: Segment = ProcessInfo.processInfo.arguments.contains("spots") ? .spots : .rooms
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18).padding(.bottom, 8)

                    switch segment {
                    case .rooms: scans
                    case .spots: spots
                    }
                }
            }
            .navigationTitle("My Home")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if segment == .spots {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAdd = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Log a dead spot")
                    }
                }
            }
            .sheet(isPresented: $showAdd) { LogDeadSpotSheet() }
        }
    }

    @ViewBuilder private var scans: some View {
        if store.sessions.isEmpty {
            ContentUnavailableView("No scans yet", systemImage: "arkit",
                                   description: Text("Run an AR scan and save it here to track your Wi-Fi score over time."))
        } else {
            List {
                ForEach(store.sessions) { s in
                    NavigationLink {
                        ScanResultView(session: s, isNew: false)
                    } label: {
                        HStack(spacing: 14) {
                            MiniHeatmap(session: s)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.name).font(.headline)
                                Text("\(s.date.formatted(.dateTime.month(.abbreviated).day())) · \(s.pins.count) dead zone\(s.pins.count == 1 ? "" : "s")")
                                    .font(.footnote).foregroundStyle(Theme.secondary)
                            }
                            Spacer()
                            Text("\(s.score)").font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(Signal.color(Double(s.score) / 100))
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .onDelete { idx in idx.map { store.sessions[$0] }.forEach(store.delete) }
            }
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder private var spots: some View {
        if store.deadZones.isEmpty {
            ContentUnavailableView {
                Label("No dead spots logged", systemImage: "mappin.slash")
            } description: {
                Text("Standing somewhere with bad Wi-Fi? Log it in two taps and keep a record for your router or provider.")
            } actions: {
                Button("Log a dead spot") { showAdd = true }.buttonStyle(.borderedProminent)
            }
        } else {
            List {
                ForEach(store.deadZones) { z in
                    HStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark").font(.title3)
                            .foregroundStyle(Signal.color(z.q))
                            .frame(width: 44, height: 44)
                            .background(Signal.color(z.q, opacity: 0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(z.room).font(.headline)
                            if !z.note.isEmpty { Text(z.note).font(.footnote).foregroundStyle(Theme.secondary) }
                            Text(z.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .font(.caption2).foregroundStyle(Theme.secondary)
                        }
                        Spacer()
                        Text("\(Signal.dBm(z.q)) dBm").font(.footnote.monospacedDigit()).foregroundStyle(Signal.color(z.q))
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .onDelete { idx in idx.map { store.deadZones[$0] }.forEach(store.delete) }
            }
            .scrollContentBackground(.hidden)
        }
    }
}

struct LogDeadSpotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WiFiMonitor.self) private var monitor
    @Environment(SessionStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @State private var room = ""
    @State private var note = ""

    private let rooms = ["Bedroom", "Living Room", "Kitchen", "Bathroom", "Office", "Garage", "Basement", "Garden", "Balcony"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Current signal") {
                    HStack {
                        Image(systemName: "wifi").foregroundStyle(Signal.color(monitor.quality))
                        Text(monitor.ssid ?? "No Wi-Fi")
                        Spacer()
                        Text("\(Signal.label(monitor.quality)) · \(Signal.dBm(monitor.quality)) dBm")
                            .foregroundStyle(Signal.color(monitor.quality))
                    }
                }
                Section("Where is it?") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(rooms, id: \.self) { r in
                                Button(r) { room = r; Haptics.tap() }
                                    .buttonStyle(.bordered)
                                    .tint(room == r ? Theme.accent : .gray)
                            }
                        }
                    }
                    TextField("Room or spot", text: $room)
                    TextField("What happens here? (optional)", text: $note)
                }
            }
            .navigationTitle("Log Dead Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(room.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .environment(\.paywallScope, "logsheet")
        .paywallSheet()
    }

    private func save() {
        if store.deadZones.count >= Config.freeDeadZoneLogLimit && !purchases.requirePro(.deadZoneLimit, scope: "logsheet") { return }
        store.add(DeadZoneEntry(room: room.trimmingCharacters(in: .whitespaces), note: note, q: monitor.quality, ssid: monitor.ssid ?? "Wi-Fi"))
        Haptics.success()
        dismiss()
    }
}
