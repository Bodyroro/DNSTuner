//
//  Journal.swift · Historique des actions
//
//  Toute action qui touche à la configuration du système y est tracée, avec son
//  résultat : c'est ce qui permet de comprendre après coup pourquoi la résolution
//  DNS a changé. Aucune donnée personnelle n'y est écrite — uniquement des noms
//  de services réseau et des adresses de résolveurs publics.
//

import Foundation

struct JournalEntry: Identifiable, Codable {
    enum Kind: String, Codable { case info, success, failure }

    let id: UUID
    let date: Date
    let kind: Kind
    let message: String

    init(kind: Kind, message: String) {
        self.id = UUID()
        self.date = Date()
        self.kind = kind
        self.message = message
    }

    var icon: String {
        switch kind {
        case .info:    return "info.circle"
        case .success: return "checkmark.circle"
        case .failure: return "xmark.octagon"
        }
    }
}

@MainActor
final class Journal: ObservableObject {
    static let shared = Journal()

    @Published private(set) var entries: [JournalEntry] = []

    private static let key = "journal"
    private static let maxEntries = 200

    private init() {
        if let data = UserDefaults.standard.data(forKey: Journal.key),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        }
    }

    func log(_ kind: JournalEntry.Kind, _ message: String) {
        entries.insert(JournalEntry(kind: kind, message: message), at: 0)
        if entries.count > Journal.maxEntries { entries.removeLast(entries.count - Journal.maxEntries) }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Journal.key)
        }
    }
}
