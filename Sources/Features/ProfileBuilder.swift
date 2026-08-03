//
//  ProfileBuilder.swift · Génération des profils de configuration DoH / DoT
//
//  macOS n'expose le DNS chiffré système-wide que de deux façons :
//   1. NEDNSSettingsManager, qui exige l'entitlement `dns-settings` (donc un
//      profil de provisioning Apple payant) — inaccessible à une app signée ad-hoc ;
//   2. un profil de configuration portant une charge utile
//      `com.apple.dnsSettings.managed`.
//  DNSTuner emprunte la seconde voie et génère le profil à la volée.
//

import Foundation

enum ProfileBuilder {

    /// Préfixe commun à tous les profils créés par l'app. Il rend la détection et
    /// la suppression fiables, et strictement limitées à nos propres profils :
    /// aucun profil MDM ou tiers ne peut être touché par erreur.
    static let identifierPrefix = "fr.bodyroro.dnstuner"

    static func identifier(for provider: DNSProvider, transport: DNSTransport) -> String {
        "\(identifierPrefix).\(provider.id).\(transport.rawValue)"
    }

    /// Construit le profil `.mobileconfig` pour un fournisseur et un transport chiffré.
    /// Renvoie `nil` si le fournisseur ne publie pas ce transport.
    static func makeProfile(for provider: DNSProvider, transport: DNSTransport) -> Data? {
        var dnsSettings: [String: Any] = [:]

        switch transport {
        case .https:
            guard let doh = provider.doh else { return nil }
            dnsSettings["DNSProtocol"] = "HTTPS"
            dnsSettings["ServerURL"] = doh
        case .tls:
            guard let dot = provider.dot else { return nil }
            dnsSettings["DNSProtocol"] = "TLS"
            dnsSettings["ServerName"] = dot
        case .plain:
            return nil
        }

        // Adresses de bootstrap : macOS doit pouvoir joindre le résolveur avant
        // d'avoir pu résoudre son propre nom d'hôte. Facultatif mais évite un
        // démarrage lent — et indispensable si le DNS du routeur est injoignable.
        if !provider.bootstrapAddresses.isEmpty {
            dnsSettings["ServerAddresses"] = provider.bootstrapAddresses
        }

        let payloadID = identifier(for: provider, transport: transport)
        let displayName = "DNSTuner — \(provider.displayName) (\(transport == .https ? "DoH" : "DoT"))"

        let payload: [String: Any] = [
            "PayloadType": "com.apple.dnsSettings.managed",
            "PayloadIdentifier": "\(payloadID).payload",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": displayName,
            "PayloadOrganization": "DNSTuner",
            "DNSSettings": dnsSettings,
        ]

        let profile: [String: Any] = [
            "PayloadType": "Configuration",
            "PayloadIdentifier": payloadID,
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
            "PayloadDisplayName": displayName,
            "PayloadDescription": T("profile.description", provider.displayName),
            "PayloadOrganization": "DNSTuner",
            // Le profil doit rester supprimable : par l'app, et par l'utilisateur
            // depuis Réglages Système. Aucun verrouillage, aucun mot de passe.
            "PayloadRemovalDisallowed": false,
            // Portée système, et non utilisateur. Un réglage DNS chiffré crée
            // une configuration réseau via le même sous-système que les VPN, qui
            // n'existe qu'au niveau de la machine : en portée utilisateur, macOS
            // refuse le profil avec « le serveur VPN n'a pas pu être créé ».
            "PayloadScope": "System",
            "PayloadContent": [payload],
        ]

        return try? PropertyListSerialization.data(fromPropertyList: profile,
                                                   format: .xml,
                                                   options: 0)
    }
}
