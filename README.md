<div align="center">

<img src="logo.png" width="120" alt="DNSTuner"/>

# DNSTuner

**Le sélecteur de DNS système pour votre Mac — clair ou chiffré, en un clic, réversible.**
*The system-wide DNS switcher for your Mac — plain or encrypted, one click, fully reversible.*

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/macOS-26_·_27-black?logo=apple)
![Chip](https://img.shields.io/badge/Apple_Silicon-only-blue)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-green)
![Langues](https://img.shields.io/badge/langues-FR_·_EN-lightgrey)

**🇫🇷 Français · 🇬🇧 English** — *Libre et open source · Free and open source*

<br/>

<img src="dashboard.png" width="880" alt="DNSTuner : catalogue de résolveurs, adresses, application au système et DNS chiffré"/>

</div>

---

## 🇫🇷 Présentation

DNSTuner bascule la résolution DNS de **tout votre Mac** vers un résolveur public choisi dans un catalogue de **46 entrées** — AdGuard, Cloudflare, Quad9, OpenDNS, Mullvad, DNS4EU, Control D, CleanBrowsing, NextDNS, dns0.eu, CZ.NIC, FDN, CIRA, Google — en clair ou **chiffré** (DoH / DoT). Il dit ensuite honnêtement **ce que chaque résolveur bloque**, en croisant ce que le fournisseur annonce avec ce que l'app **mesure réellement**.

Un principe constant : *rien n'est fait dans votre dos, tout est réversible.* Les DNS d'origine de chaque service réseau sont mémorisés avant la première écriture, et rétablis à l'identique d'un clic. DNSTuner n'utilise que des outils documentés d'Apple (`networksetup`, `scutil`, `dscacheutil`, `profiles`) — aucun fichier système n'est modifié, aucun démon n'est installé, aucun droit permanent n'est conservé.

## 🇬🇧 Overview

DNSTuner switches your **entire Mac's** DNS resolution to a public resolver picked from a **46-entry catalog** — AdGuard, Cloudflare, Quad9, OpenDNS, Mullvad, DNS4EU, Control D, CleanBrowsing, NextDNS, dns0.eu, CZ.NIC, FDN, CIRA, Google — plain or **encrypted** (DoH / DoT). It then tells you honestly **what each resolver blocks**, cross-checking the provider's claims against what the app actually **measures**. Nothing happens behind your back and everything is reversible: your original per-service DNS is saved before the first write and restored exactly, in one click.

## Fonctionnalités · Features

| | |
|---|---|
| 📊 **Tableau de bord** | Une note de protection, le résolveur actif avec son **drapeau de juridiction**, la latence mesurée, l'état des services réseau, les compteurs du catalogue, la couverture par catégorie et les dernières actions — en un écran. |
| 🧭 **Fournisseurs** | Catalogue de **46 résolveurs** groupés par éditeur, recherche par nom ou par adresse, filtres par catégorie bloquée, favoris. Application à **tous les services réseau** en une seule demande de mot de passe. |
| 🔒 **DNS chiffré** | **DoH et DoT** par profil de configuration `com.apple.dnsSettings.managed` : installation guidée en deux clics, **désinstallation directement depuis l'app**. |
| 📊 **Comparatif** | Matrice « que bloque quoi » sur **7 catégories** — publicités, traqueurs, malware, contenu adulte, jeux d'argent, réseaux sociaux, domaines récents — annonce du fournisseur **et** mesure réelle superposées. |
| 🎯 **Note de blocage** | Un panel de **40 domaines témoins** — régies publicitaires, traqueurs, télémétrie, widgets sociaux, malware, contenu adulte — interrogés un par un, avec une **note sur 100** et un niveau de protection. Chaque domaine est nommé, avec ce qu'il sert et la réponse obtenue : on voit exactement ce qui passe et ce qui ne passe pas. La note apparaît aussi sur le tableau de bord. |
| 🩺 **Diagnostic** | Dix tests sur la configuration **réellement active** : chiffrement, résolveur sortant, transmission de votre sous-réseau (ECS), validation DNSSEC, détournement des NXDOMAIN, protection anti-rebinding, et blocage effectif des publicités, traqueurs, malware et contenu adulte. Chaque test montre la mesure brute. |
| ⚡ **Test** | Latence médiane et **blocage effectif** de chaque résolveur, sans rien changer sur la machine. Interrogation via `dig` en clair, ou en **DoH filaire (RFC 8484)** pour les fournisseurs sans adresse publique comme Mullvad. |
| 🔍 **État** | Ce que le système résout **vraiment** (`scutil --dns`), le DNS déclaré service par service, l'état de chiffrement et les profils DNSTuner installés. |
| ↩️ **Retour arrière** | DNS d'origine mémorisés avant la première écriture et rétablis à l'identique. Le bouton « Rétablir » retire aussi le profil chiffré, qui primerait sinon sur la configuration restaurée. |
| 🎛️ **Personnalisé** | Résolveur hors catalogue (adresses IPv4/IPv6 + URL DoH), avec validation stricte des adresses. |
| 📓 **Journal** | Chaque action sur la configuration, avec son résultat. Aucune donnée personnelle : uniquement des noms de services réseau et des adresses de résolveurs publics. |
| ⚙️ **Réglages** *(icône ronde)* | Langue, résolveur personnalisé, et la section **« Ce qu'un DNS filtrant ne peut pas faire »**. |

## Ce que macOS permet — et ce qu'il refuse

Le DNS chiffré système-wide n'a que **deux** portes d'entrée sur macOS, et une seule est ouverte à une app signée en ad-hoc :

- ❌ **`NEDNSSettingsManager`** (Network Extension) — exige l'entitlement `com.apple.developer.networking.networkextension` avec la valeur `dns-settings`, donc un profil de provisioning délivré par un compte développeur Apple payant. Inaccessible ici.
- ✅ **Profil de configuration** `com.apple.dnsSettings.managed`, en **portée système** — une configuration DNS chiffrée passe par le même sous-système que les VPN, qui n'existe qu'au niveau de la machine ; en portée utilisateur, macOS refuse le profil. Voie retenue, avec une asymétrie qu'il faut connaître : **`profiles install` est déprécié depuis macOS 11** (*« You should add your profiles using the System Settings Profiles preference pane »*), donc l'installation passe obligatoirement par votre validation dans **Réglages Système › Général › Gestion des appareils**. En revanche **`profiles remove -identifier` reste scriptable** : le bouton « Désactiver » de l'app fonctionne pleinement.

Deux pièges du DNS sur macOS, traités explicitement par l'app :

- **Le DNS n'est pas global, il est par service réseau.** Ne régler que le Wi-Fi laisse l'Ethernet et le Thunderbolt Bridge sur le DNS du routeur. DNSTuner écrit sur tous les services activés, en concaténant les commandes en un script unique — **une seule demande de mot de passe**, pas une par interface.
- **`networksetup -getdnsservers` ment par omission** : un service en DHCP y apparaît vide alors qu'il résout parfaitement. La vérité terrain est `scutil --dns`, que l'onglet **État** affiche en premier.

Les mécanismes réellement utilisés, tous documentés par Apple :

| Capacité | Mécanisme | Privilèges |
|---|---|---|
| Définir le DNS d'un service | `networksetup -setdnsservers <service> <adresses…>` | administrateur |
| Revenir au DNS du routeur | `networksetup -setdnsservers <service> Empty` | administrateur |
| Lire le DNS déclaré | `networksetup -getdnsservers <service>` | aucun |
| Lister services et interfaces | `networksetup -listnetworkserviceorder` | aucun |
| Lire le DNS **réellement utilisé** | `scutil --dns` | aucun |
| Vider le cache de résolution | `dscacheutil -flushcache` + `killall -HUP mDNSResponder` | administrateur |
| Détecter les profils installés | `profiles status -type configuration` | aucun |
| **Supprimer un profil** | `profiles remove -identifier <id>` | administrateur |

*🇬🇧 System-wide encrypted DNS has only two entry points on macOS. `NEDNSSettingsManager` needs a paid-account entitlement and is out of reach for an ad-hoc signed app; a configuration profile is the way in. Note the asymmetry: `profiles install` has been deprecated since macOS 11 (installation requires your approval in System Settings), while `profiles remove -identifier` is still scriptable — so the app's "Disable" button works fully.*

## Ce qui est bloquable — et ce qui ne l'est pas

Le blocage DNS agit sur **un nom de domaine entier** : le résolveur répond `NXDOMAIN` ou une adresse puits, et rien ne se connecte. Selon le fournisseur, cela couvre les **publicités**, les **traqueurs**, le **malware et le hameçonnage**, le **contenu adulte**, les **jeux d'argent**, les **réseaux sociaux** et les **domaines fraîchement enregistrés**.

Ce que le DNS ne peut **pas** faire — l'app le dit dans ses Réglages, pas seulement ici :

1. Les publicités servies depuis le domaine du contenu (YouTube, Instagram, Twitch) ne peuvent pas être bloquées sans casser le service entier.
2. Le DNS ne voit qu'un nom de domaine : jamais le chemin d'une URL, jamais le contenu d'une page.
3. Chrome et Firefox peuvent activer leur propre DoH et court-circuiter le résolveur du système.
4. Un VPN actif, ou une app au DNS codé en dur, échappe au réglage.
5. Un filtrage strict provoque des faux positifs — d'où la présence de plusieurs résolveurs **sans filtrage** dans le catalogue, pour diagnostiquer.

### Écart assumé avec AdGuard Home

| | AdGuard Home | DNSTuner |
|---|---|---|
| Résolveur local | oui | non |
| Listes de filtrage personnalisables | oui | non — celles du fournisseur |
| Règles par domaine, journal des requêtes | oui | non |
| Démon root à maintenir | oui | **non** |
| Réversibilité en un clic | partielle | **totale** |

DNSTuner choisit délibérément le second modèle : aucun processus privilégié permanent, aucune liste à tenir à jour, et un retour arrière complet garanti.

## Sécurité

Uniquement des outils documentés d'Apple — `networksetup`, `scutil`, `dscacheutil`, `profiles`. **Aucun fichier système n'est modifié**, aucun démon n'est installé, aucun droit permanent n'est conservé. Les suppressions de profils sont **bornées au préfixe `fr.bodyroro.dnstuner.`** : un profil MDM ou tiers ne peut pas être touché, même par erreur. Toute adresse saisie à la main est validée (`IPAddress.isValid`) avant écriture — une adresse invalide dans `networksetup` couperait la résolution DNS de la machine.

Le catalogue porte un champ `verifiedOn` : les entrées dont les adresses n'ont pas pu être relues sur la documentation officielle du fournisseur sont **signalées dans l'interface** par un avertissement explicite, jamais présentées comme vérifiées.

## Langues · Languages

Interface entièrement **française et anglaise**, changement à chaud depuis les Réglages. Aucune chaîne en dur : tout passe par `L10n.t("clé")` (`Sources/Strings.swift`).

## Installation

**DNSTuner se compile depuis les sources.** Il n'y a pas d'archive à télécharger : le
code est ici, vous produisez vous-même le binaire que vous exécutez. C'est le seul
moyen d'être certain que l'app fait exactement ce que le code dit.

Prérequis : **macOS 26 ou 27**, Mac **Apple Silicon** (M1 à M4), et les *Command
Line Tools* d'Apple. Aucune dépendance externe, pas de Xcode requis.

```bash
xcode-select --install          # une seule fois, si ce n'est pas déjà fait
git clone https://github.com/Bodyroro/DNSTuner.git
cd DNSTuner
./build.sh
```

`build.sh` compile toutes les sources, cible **macOS 26.0** (garantit la compatibilité 26 **et** 27), génère l'icône depuis `logo.png`, signe le bundle en ad-hoc et lance l'app.

L'app se lance à la fin de la compilation. Pour l'installer durablement, glissez
**DNSTuner.app** dans votre dossier **Applications**.

> Le bundle est signé en **ad-hoc**, pas notarisé : il est valide sur votre
> machine puisque vous venez de le produire. Aucune manipulation de Gatekeeper
> n'est nécessaire — celle-ci ne concernait que les archives téléchargées.

Compilation manuelle équivalente, si vous préférez voir chaque étape :

```bash
swiftc -O -parse-as-library -target arm64-apple-macos26.0 \
  Sources/**/*.swift Sources/*.swift \
  -o DNSTuner.app/Contents/MacOS/DNSTuner
codesign --force --sign - DNSTuner.app
open DNSTuner.app
```

*English — DNSTuner is built from source; there is no download. Install Apple's
Command Line Tools, clone the repository, run `./build.sh`, then move
**DNSTuner.app** to **Applications**. Requires macOS 26 or 27 on Apple Silicon.*

## Architecture

```
dnstuner/
├── build.sh                  Compilation + signature + lancement
├── logo.png                  Icône source
├── dashboard.png             Capture du tableau de bord (README)
├── Sources/
│   ├── App/                  Point d'entrée, TabView, barre d'outils
│   ├── Core/
│   │   ├── Shell.swift            Exécution de commandes, élévation, échappements
│   │   ├── NetworkServices.swift  Services réseau, scutil --dns, PTR, passerelle
│   │   ├── HardwareVendor.swift   Fabricant d'après l'OUI (registre IEEE)
│   │   └── Journal.swift          Historique persistant des actions
│   ├── Features/
│   │   ├── DNSProvider.swift      Modèle, catégories, transports, pays
│   │   ├── ProviderCatalog.swift  Les 46 résolveurs, champ verifiedOn
│   │   ├── DNSEngine.swift        Application / lecture / restauration du DNS clair
│   │   ├── ProfileBuilder.swift   Génération des .mobileconfig DoH / DoT
│   │   ├── ProfileManager.swift   Installation guidée, détection, suppression
│   │   ├── DNSTester.swift        Latence + blocage réel (dig et DoH filaire)
│   │   ├── DiagnosticEngine.swift Dix tests sur la configuration active
│   │   ├── BlockingAudit.swift    40 domaines témoins, note sur 100
│   │   ├── Persistence.swift      Favoris, DNS d'origine, onglet, validation
│   │   └── AppModel.swift         État partagé, onglets, résumé du bandeau
│   ├── UI/
│   │   ├── Components.swift       Palette encre de nuit, cartes, animations
│   │   ├── FlagView.swift         Drapeaux dessinés en rectangle
│   │   └── LiquidGauge.swift      Bille de note à remplissage animé
│   ├── Views/                Une vue par onglet, plus AuditSection
│   ├── Strings.swift         Table de traduction FR / EN
│   └── Localization.swift    L10n.t("clé")
└── DNSTuner.app/             Bundle (Info.plist versionné)
```

## Sources

- AdGuard — Fournisseurs DNS connus : <https://adguard-dns.io/kb/fr/general/dns-providers/>
- DNS4EU : <https://www.joindns4.eu/for-public>
- Apple — `man networksetup`, `man scutil`, `man profiles`
- Apple — Device Management, charge utile DNS Settings : <https://developer.apple.com/documentation/devicemanagement/dnssettings>

Adresses du catalogue vérifiées le **2026-07-26**. Entrées non revérifiées à cette date, signalées dans l'app : FDN, dns0.eu ZERO, dns0.eu KIDS, CIRA Famille.

## Licence

MIT — © 2026 Bodyroro. Voir [LICENSE](LICENSE).
