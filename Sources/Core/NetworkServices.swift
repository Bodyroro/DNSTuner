//
//  NetworkServices.swift · Énumération des services réseau macOS
//
//  Le DNS se règle *par service réseau* (Wi-Fi, Ethernet, Thunderbolt Bridge…),
//  pas globalement : pour un réglage réellement « système », il faut donc les
//  appliquer à tous. Ce fichier fournit la liste et l'état de chacun.
//

import Foundation

struct NetworkService: Identifiable, Hashable {
    let name: String        // « Wi-Fi », « Ethernet »…
    let device: String      // « en0 », « en1 »… (vide si inconnu)
    let enabled: Bool       // service activé dans Réglages Réseau
    let isUp: Bool          // interface physiquement active (câble branché, Wi-Fi associé)

    var id: String { name }
    /// Services que l'on configure réellement : inutile d'écrire sur un service désactivé.
    var isConfigurable: Bool { enabled }
}

enum NetworkServices {

    private static let networksetup = "/usr/sbin/networksetup"

    /// Liste tous les services réseau avec leur interface et leur état.
    ///
    /// `networksetup -listnetworkserviceorder` donne le couple service ↔ device en
    /// une seule commande, ce qui évite un appel par service. Les services
    /// désactivés y sont préfixés par `(*)`.
    static func all() -> [NetworkService] {
        let output = Shell.run(networksetup, ["-listnetworkserviceorder"])
        var services: [NetworkService] = []
        var pendingName: String?
        var pendingEnabled = true

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("("), line.contains("Hardware Port:") {
                // « (Hardware Port: Wi-Fi, Device: en1) »
                guard let name = pendingName else { continue }
                let device = line.components(separatedBy: "Device:").last?
                    .replacingOccurrences(of: ")", with: "")
                    .trimmingCharacters(in: .whitespaces) ?? ""
                services.append(NetworkService(name: name,
                                               device: device,
                                               enabled: pendingEnabled,
                                               isUp: interfaceIsUp(device)))
                pendingName = nil
                pendingEnabled = true

            } else if line.hasPrefix("("), let close = line.firstIndex(of: ")") {
                // « (1) Wi-Fi » ou « (*) Bluetooth PAN » pour un service désactivé.
                let marker = String(line[line.index(after: line.startIndex)..<close])
                let name = String(line[line.index(after: close)...])
                    .trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                pendingName = name
                pendingEnabled = (marker != "*")
            }
        }
        return services
    }

    /// Services sur lesquels DNSTuner écrit : ceux activés dans Réglages Réseau.
    static func configurable() -> [NetworkService] {
        all().filter(\.isConfigurable)
    }

    /// Nom d'hôte d'une adresse IP, par résolution inverse.
    ///
    /// C'est ce qui permet de nommer le résolveur au lieu d'afficher une adresse
    /// nue : une box de FAI répond en général son nom local (`livebox.home`,
    /// `freebox.home`…), un résolveur public le nom de son opérateur.
    /// Délais courts et un seul essai : sans réponse, on retombe sur l'adresse.
    static func reverseName(_ ip: String) -> String? {
        let r = Shell.runResult("/usr/bin/dig",
                                ["-x", ip, "+short", "+time=1", "+tries=1"])
        guard r.ok else { return nil }
        guard var name = r.trimmedOut.split(separator: "\n").first.map(String.init),
              !name.isEmpty else { return nil }
        if name.hasSuffix(".") { name.removeLast() }
        // Une résolution inverse peut renvoyer un enregistrement non-PTR ; on
        // n'accepte qu'un nom de domaine plausible.
        guard name.contains("."), !IPAddress.isValid(name) else { return nil }
        return name
    }

    /// Passerelle par défaut du réseau. Sert à savoir si le résolveur actif est
    /// la box elle-même — le cas le plus fréquent quand aucun DNS n'est réglé.
    static func defaultGateway() -> String? {
        let r = Shell.runResult("/sbin/route", ["-n", "get", "default"])
        guard r.ok else { return nil }
        for line in r.out.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("gateway:") {
                let value = l.replacingOccurrences(of: "gateway:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Adresse matérielle d'une IP du réseau local, lue dans la table ARP.
    /// Locale et non transmise : seul le nom du fabricant qu'on en déduit est affiché.
    /// Lecture passive et sans garantie : depuis macOS 15, la table ARP n'est
    /// visible que d'un processus autorisé à accéder au réseau local. DNSTuner
    /// ne réclame pas cette autorisation — la déclencher pour un simple libellé
    /// serait disproportionné — et se contente du renseignement quand il est là.
    static func macAddress(for ip: String) -> String? {
        arpLookup(ip)
    }

    private static func arpLookup(_ ip: String) -> String? {
        let r = Shell.runResult("/usr/sbin/arp", ["-n", ip])
        guard r.ok else { return nil }
        // « ? (192.168.1.254) at 38:7:16:77:3a:13 on en1 ifscope [ethernet] »
        guard let atRange = r.out.range(of: " at ") else { return nil }
        let rest = r.out[atRange.upperBound...]
        guard let mac = rest.split(separator: " ").first.map(String.init),
              mac.contains(":"), !mac.contains("incomplete") else { return nil }
        return mac
    }

    /// Vrai si l'adresse appartient à un réseau privé — donc à une box ou à un
    /// résolveur local, pas à un service public.
    static func isPrivate(_ ip: String) -> Bool {
        if ip.hasPrefix("10.") || ip.hasPrefix("192.168.") || ip.hasPrefix("127.") { return true }
        if ip.hasPrefix("172.") {
            let parts = ip.split(separator: ".")
            if parts.count > 1, let second = Int(parts[1]), (16...31).contains(second) { return true }
        }
        // IPv6 : adresses uniques locales (fc00::/7) et lien-local (fe80::/10).
        let lower = ip.lowercased()
        if lower.hasPrefix("fd") || lower.hasPrefix("fc") || lower.hasPrefix("fe80") { return true }
        return false
    }

    private static func interfaceIsUp(_ device: String) -> Bool {
        guard !device.isEmpty else { return false }
        let r = Shell.runResult("/sbin/ifconfig", [device])
        return r.ok && r.out.contains("status: active")
    }

    /// DNS actuellement déclarés pour un service, tels que vus par `networksetup`.
    /// Renvoie un tableau vide quand le service hérite du DNS fourni par DHCP.
    static func dnsServers(for service: String) -> [String] {
        let r = Shell.runResult(networksetup, ["-getdnsservers", service])
        guard r.ok else { return [] }
        let lines = r.out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        // Message littéral d'Apple quand rien n'est configuré :
        // « There aren't any DNS Servers set on Wi-Fi. »
        if lines.contains(where: { $0.contains("aren't any DNS Servers") }) { return [] }
        return lines.filter { !$0.isEmpty }
    }

    /// Résolveurs réellement utilisés par le système (resolver #1 de `scutil --dns`).
    /// C'est la vérité terrain : elle inclut le DNS poussé par DHCP et reflète un
    /// éventuel profil de configuration DoH/DoT actif.
    static func activeResolvers() -> [String] {
        let output = Shell.run("/usr/sbin/scutil", ["--dns"])
        var result: [String] = []
        var inFirstResolver = false
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("resolver #") {
                if inFirstResolver { break }          // on ne garde que le resolver #1
                inFirstResolver = (line == "resolver #1")
                continue
            }
            guard inFirstResolver, line.hasPrefix("nameserver[") else { continue }
            if let value = line.components(separatedBy: ":").dropFirst().joined(separator: ":")
                .trimmingCharacters(in: .whitespaces) as String?, !value.isEmpty {
                result.append(value)
            }
        }
        return result
    }
}
