import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    var sessions: [ScanSession] = []
    var deadZones: [DeadZoneEntry] = []

    private let sessionsURL: URL
    private let deadZonesURL: URL

    init() {
        let dir = URL.documentsDirectory
        sessionsURL = dir.appending(path: "sessions.json")
        deadZonesURL = dir.appending(path: "deadzones.json")
        if Config.isDemo {
            sessions = [DemoData.session(name: "After moving the router", shifted: true), DemoData.session(name: "My Apartment")]
            deadZones = [
                DeadZoneEntry(room: "Bedroom", note: "Video calls drop here", q: 0.07, ssid: "Home-5G", date: .now.addingTimeInterval(-86400)),
                DeadZoneEntry(room: "Garage", note: "No signal at all", q: 0.0, ssid: "Home-5G", date: .now.addingTimeInterval(-86400 * 3)),
                DeadZoneEntry(room: "Balcony", note: "Streaming buffers", q: 0.19, ssid: "Home-5G", date: .now.addingTimeInterval(-86400 * 6))
            ]
        } else {
            sessions = load(sessionsURL)
            deadZones = load(deadZonesURL)
        }
    }

    func add(_ session: ScanSession) {
        sessions.insert(session, at: 0)
        persist()
    }

    func update(_ session: ScanSession) {
        guard let i = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[i] = session
        persist()
    }

    func delete(_ session: ScanSession) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }

    func add(_ entry: DeadZoneEntry) {
        deadZones.insert(entry, at: 0)
        persist()
    }

    func delete(_ entry: DeadZoneEntry) {
        deadZones.removeAll { $0.id == entry.id }
        persist()
    }

    private func persist() {
        guard !Config.isDemo else { return }
        try? JSONEncoder().encode(sessions).write(to: sessionsURL, options: .atomic)
        try? JSONEncoder().encode(deadZones).write(to: deadZonesURL, options: .atomic)
    }

    private func load<T: Decodable>(_ url: URL) -> [T] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }
}
