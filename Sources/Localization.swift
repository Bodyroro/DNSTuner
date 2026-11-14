//
//  Localization.swift · Système de traduction, 45 langues
//  Toutes les chaînes de l'interface passent par L10n.t("clé") ou LStr. Aucun texte en dur.
//  Français et anglais vivent dans le code (Strings.table, LStr) ; les autres langues dans
//  Langues/<code>.json, texte français vers traduction (Outils/Parc/LanguesMac.py).
//

import SwiftUI

struct Lang: Hashable, Identifiable {
    let code: String
    var id: String { code }

    static let fr = Lang(code: "fr")
    static let en = Lang(code: "en")

    /// Les 45 langues du parc : français et anglais en tête, les autres par nom.
    static let allCases: [Lang] = [fr, en] + [
        "ar", "bn", "ca", "cs", "da", "de", "el", "es", "fi", "gu", "he", "hi", "hr", "hu", "id", "it", "ja",
        "kn", "ko", "ml", "mr", "ms", "nb", "nl", "or", "pa", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl",
        "sv", "ta", "te", "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant",
    ].map(Lang.init).sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

    /// Nom de la langue dans cette langue (« Deutsch », « 日本語 »).
    var displayName: String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }

    var isRightToLeft: Bool { Locale.Language(identifier: code).characterDirection == .rightToLeft }

    /// Langue du système la plus proche parmi celles de l'app, anglais à défaut.
    static var system: Lang {
        let codes = [en.code] + allCases.map(\.code).filter { $0 != en.code }
        let best = Bundle.preferredLocalizations(from: codes, forPreferences: Locale.preferredLanguages).first
        return allCases.first { $0.code == best } ?? en
    }
}

/// Source de vérité de la langue courante. Observable → l'UI se retraduit à chaud.
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published private(set) var lang: Lang
    /// Texte français vers traduction, pour les langues hors français et anglais.
    private var translations: [String: String] = [:]

    static let storageKey = "appLanguage"

    private init() {
        let saved = UserDefaults.standard.string(forKey: L10n.storageKey)
        lang = Lang.allCases.first { $0.code == saved } ?? .system
        translations = Self.translations(for: lang)
    }

    func set(_ l: Lang) {
        UserDefaults.standard.set(l.code, forKey: L10n.storageKey)
        translations = Self.translations(for: l)
        lang = l
    }

    private static func translations(for lang: Lang) -> [String: String] {
        guard lang != .fr, lang != .en,
              let url = Bundle.main.url(forResource: lang.code, withExtension: "json", subdirectory: "Langues"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return table
    }

    /// Texte dans la langue courante. Repli sur l'anglais, puis sur le français.
    func text(fr: String, en: String) -> String {
        let english = en.isEmpty ? fr : en
        switch lang {
        case .fr: return fr
        case .en: return english
        default: return translations[fr] ?? english
        }
    }

    /// Traduction d'une clé. Repli sur la clé brute si elle n'existe pas.
    func t(_ key: String) -> String {
        guard let entry = Strings.table[key], let fr = entry[.fr] else { return key }
        return text(fr: fr, en: entry[.en] ?? "")
    }

    /// Traduction avec arguments (ex. « %d services »).
    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }
}

/// Raccourci global pour les contextes hors-vue (moteurs, catalogues).
func T(_ key: String) -> String { L10n.shared.t(key) }
func T(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.shared.t(key), arguments: args)
}

/// Chaîne co-localisée avec la donnée (catalogue de fournisseurs) : français et anglais dans le code, les
/// autres langues dans Langues/.
struct LStr {
    let fr: String
    let en: String
    init(_ fr: String, _ en: String) { self.fr = fr; self.en = en }
    var current: String { L10n.shared.text(fr: fr, en: en) }
}
