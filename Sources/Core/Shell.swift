//
//  Shell.swift · Exécution de commandes système
//
//  DNSTuner n'utilise que des outils Apple documentés : networksetup, scutil,
//  dscacheutil, profiles. Aucune modification de fichier système.
//

import Foundation

enum Shell {
    /// Résultat complet d'une commande : sortie, erreur et code de sortie.
    struct Result {
        let out: String
        let err: String
        let code: Int32
        var ok: Bool { code == 0 }
        var trimmedOut: String { out.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    @discardableResult
    static func runResult(_ path: String, _ args: [String]) -> Result {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        do { try p.run() } catch { return Result(out: "", err: "\(error)", code: -1) }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return Result(out: String(data: outData, encoding: .utf8) ?? "",
                      err: String(data: errData, encoding: .utf8) ?? "",
                      code: p.terminationStatus)
    }

    @discardableResult
    static func run(_ path: String, _ args: [String]) -> String {
        runResult(path, args).out
    }

    @discardableResult
    static func sh(_ cmd: String) -> String { run("/bin/sh", ["-c", cmd]) }

    /// Échappe une chaîne pour l'insérer dans un littéral AppleScript.
    /// Indispensable : les commandes contiennent des guillemets (noms de services
    /// réseau comme « Thunderbolt Bridge ») qui casseraient le script sinon.
    private static func appleScriptEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Échappe une chaîne pour l'insérer entre guillemets simples dans un shell.
    static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Exécute une commande avec les droits administrateur via l'invite système.
    /// Une seule invocation = une seule demande de mot de passe : les appelants
    /// concatènent donc toutes leurs commandes en un unique script.
    @discardableResult
    static func admin(_ cmd: String) -> Result {
        let script = "do shell script \"\(appleScriptEscaped(cmd))\" with administrator privileges"
        let r = runResult("/usr/bin/osascript", ["-e", script])
        // osascript renvoie -128 quand l'utilisateur annule l'invite de mot de passe.
        return r
    }

    /// Vrai si l'utilisateur a annulé l'invite de mot de passe (plutôt qu'un échec réel).
    static func wasCancelled(_ r: Result) -> Bool {
        r.err.contains("-128") || r.err.localizedCaseInsensitiveContains("User canceled")
    }
}
