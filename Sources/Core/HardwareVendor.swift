//
//  HardwareVendor.swift · Fabricant d'un équipement réseau, d'après son OUI
//
//  Quand le résolveur actif est la passerelle du réseau, il n'a en général ni
//  nom d'hôte ni enregistrement PTR : « 192.168.1.254 » ne dit rien à personne.
//  Son adresse matérielle, elle, porte un préfixe constructeur (OUI) attribué
//  par l'IEEE — c'est ce qui permet d'afficher « Freebox » ou « Sagemcom ».
//
//  Tout est local : l'adresse matérielle est lue dans la table ARP du Mac et
//  n'est jamais transmise, ni journalisée. Seul le nom du fabricant est affiché.
//
//  Table extraite du registre public de l'IEEE (standards-oui.ieee.org), le
//  2026-07-26. Elle couvre les fabricants de box d'opérateur et de routeurs
//  grand public ; les généralistes aux milliers de préfixes (Apple, Cisco,
//  Huawei, Xiaomi) en sont exclus — ils n'apportent rien pour une passerelle.
//

import Foundation

enum HardwareVendor {

    /// Nom du fabricant correspondant à une adresse matérielle, ou `nil`.
    /// L'adresse est normalisée : macOS écrit « 38:7:16:… » sans zéro de tête.
    static func name(forMAC mac: String) -> String? {
        let hex = mac.split(separator: ":")
            .map { $0.count == 1 ? "0" + $0 : $0 }
            .joined()
            .lowercased()
        guard hex.count >= 6 else { return nil }
        return index[String(hex.prefix(6))]
    }

    /// Index construit une fois, en découpant chaque chaîne par tranches de six.
    /// Une simple recherche de sous-chaîne donnerait des faux positifs : deux
    /// préfixes voisins forment, à cheval, une séquence de six caractères qui
    /// peut correspondre à un OUI bien réel appartenant à un autre fabricant.
    private static let index: [String: String] = {
        var map: [String: String] = [:]
        for entry in table {
            var i = entry.ouis.startIndex
            while i < entry.ouis.endIndex {
                let j = entry.ouis.index(i, offsetBy: 6, limitedBy: entry.ouis.endIndex)
                    ?? entry.ouis.endIndex
                map[String(entry.ouis[i..<j])] = entry.name
                i = j
            }
        }
        return map
    }()

    /// Un fabricant, et tous ses préfixes concaténés. Le format compact évite
    /// un millier de lignes pour une table qui ne sert qu'à une recherche.
    private static let table: [(name: String, ouis: String)] = [
        ("Freebox",
         "0007cb0024d4140c762066cf34279238071668a37870fc8f8c69148c97eadc00b0e49e12f4cae5"
        ),
        ("Sagemcom",
         "000e5900155600194b001bbf001e74001f950023480025690026910037b700604c00789e00cb5100f8cc04e31a083e5d" +
         "0851f2087b1208d59d0cac8a100645102baa10d7b0180c7a181e7818622c186a811890d82035432047b5209a7d20b82b" +
         "2420c7244750244ecd247f20289efc2c2b862c39962c79d72ce4122cf2a52cfb0f3024783067a13093bc30f60034495b" +
         "3453d2345d9e346b46348aae34db9c3817b13835fb38a65938e1f43c17103c58363c585d3c81d84065a340c72940f201" +
         "44053f44152444adb144d45344d45444e9dd4829524883c748aabb48d24f48e27e4c17eb4c195d506f0c543ced5447cc" +
         "5464d954b27e580e85581dd8582ff758687a5890435cb13e5cfa256045cd6418df646624647999647b1e64fa2b64fd96" +
         "6815906867c768aba96c2e856c99616cbab86cffce700b01707da1786559788daf78c2137c034c7c03d87c16897c2664" +
         "7c98247cd4a87ce87f8020da841ea3843e0384a06e84a1d184a423880fa288a6c68c10d48c9a8f8cc5b48cfdde90013b" +
         "904d4a907282943c9694988f94fef4981e19984265988b5d9c2472a01b29a02ddba039eea039f9a03c20a0551fa07f8a" +
         "a08e78a408f5a42249a4e0e6a86abba89a93ac3b77ac84c9acd75bb01ff4b05b99b0924ab0982bb0b28fb0bbe5b0fc88" +
         "b43b52b86685b86af1b88c2bb8d94db8ee0ebc33dbbcd5edc03c04c0ac54c0d044c0fd6fc4eb39c4eb41c4eb42c4eb43" +
         "c891f9c8cd72cc00f1cc33bbcc5830cc5c75ccfaf1d01bf4d05794d06dc9d06eded084b0d0cf0ed427ffd45039d4b5cd" +
         "d4f829d833b7d86ce9d87d7fd8a756d8cf61d8d775dc9272dc97e6e04f95e4c0e2e8ada6e8be81e8d2ffe8f1b0ec50a6" +
         "ecb157ecbeddecfc2ff04dd4f07b65f08175f08261f40595f46beff4eb38f8084ff8ab05fc6637"
        ),
        ("Technicolor",
         "000e5000147f0018f6001d68001f9f0024170026440090d00876ff1ce4dd2c301a38f18ff01628"
        ),
        ("AVM",
         "00040e00150c001a4f001c4a001f3f0024fe04b4fe0896d708b6570c72741ced6f2465112c3afd2c91ab3431c43481c4" +
         "34e1a93810d53c37123ca62f444e6d485d3550e6365c497960b58d74427f7cff4d802395989bcb98a9659cc7a6a052ab" +
         "b0f208b4fc7dbc0543c02506c80e14ccce1ed012cbd424dddc15c8dc396fe00855e0286de8df70f0b014"
        ),
        ("Arcadyan",
         "0012bf001a2a001d1900230800264d04098604705604a2220827a80c8e2918588018604118828c1883bf18a5ff1cc63c" +
         "1cf43f2037f02c591730b1b534194d3806e63cbdc53cf08344fe3b488d364c09d44c1b864c22f3507e5d543d6054b7bd" +
         "54c45b5cdc966045e8608d266095f86475da647d4d64cc226c15db703e767085367097417431707490bc78dd127c4fb5" +
         "8082fe84900a849ca684a32988035588252c8c19b58c77798c8394946ab09c80dfa0b549a4cedaa8a237a8d3f7ac1007" +
         "acb687acdf9fb83babb8f853bc30d9bcaf6ebcf87ec0d7aac4e532c899b2ccb148ccd42ed0052ad463fed48660dcf51b" +
         "e05163e09559e43ed7e475dcec6c9aecf451f08620f4cae7f83eb0fc3da5"
        ),
        ("Askey",
         "0011f50016e3001b9e0021630024d20026b60090960833ed086a0a08b0551c24cd1cb04424ec992ceadc3888714cabf8" +
         "4cedde505fb57493da7829ed7cb7337cdb9880787188337488de7c88feb690d3cf940f3b94325194917f94c2efa0648f" +
         "a08a06a49733b0eabcb4749fb482feb4eeb4c0d962c8b422d47bb0d8fb5edc08dae0ca94e0cec3e839dfe8d11bf45246" +
         "f46942f85b3bfc1263fcb4e6"
        ),
        ("Zyxel",
         "0013490019cb0023f800a0c504bf6d0826971071b3107bef14337514360e14c7c41c740d28285d30157730bd133cf75d" +
         "404a03445e824463c248ede64c9eff4cc53e5067f050e03954833a588bf35c648e5c6a805ce28c5cf4ab60319764dd68" +
         "6c4f897049a278c57d7c771680ea0b88acc088f3d58c5973909f2290ef68980d67a0e4cbb0b2dcb8d526b8eca3bc7ec3" +
         "bc9911bccf4fc02e5fc49a31c83374c8544bc86c87cc5d4ed41ad1d43df3d8912ad8ece5e4186be8377aec3eb3ec43f6" +
         "f08756f44d5cf80da9fc22f4fc9f2afcf528"
        ),
        ("Netgear",
         "00095b000fb500146c00184d001b2f001e2a001f3300223f0024b20026f2008ef204a15108028e0836c908bd43100c6b" +
         "100d7f10da431459c0200cc8204e7f20e52a28808828940128c68e2c30332cb05d30469a3498b53894ed3c3786405d82" +
         "4494fc44a56e4c60de504a6e506a0354077d6cb0ce6ccdd674440178d29480377380cc9c841b5e8c3bad941865943b22" +
         "94a67e9c3dcf9cc9eb9cd36da00460a021b7a040a0a06391a42b8cb03956b07fb9b0b98abca511c03f0ec0ffd4c40415" +
         "c43dc7c8102fc89e43cc40d0dcef09e0469ae046eee091f5e0c250e4f4c6e8fcaff87394"
        ),
        ("TP-Link",
         "000aeb0014780019e0001d0f0021270023cd002586002719003192005f67040f6604c84504f9f8081f710857000c4b54" +
         "0c722c0c80630c82680cef151027f5105a9510feed14759014869214cc2014cf9214d86414e6e414ebb618694518a6f7" +
         "18d6c718f22c1c3bf31c44191c61b41cfa68202351203626206be720dce620e15d242fd0245a5f246968282cb22887ba" +
         "28910428ee522c79be30689330b49e30b5c230de4b30fc683460f934967234e89434f7163883453c06a73c46d83c52a1" +
         "3c64cf3c6a483c6ad23c78953c846a40169f403f8c40959540ae3040ed0044669044b32d480eec482254485f08487d2e" +
         "48c3814c10d5503dd1503eaa5091e350bd5f50c7bf50d4f750fa8454759554a70354af9754c80f54e6fc58044f584120" +
         "58d8125c628b5c63bf5c899a5ca64f5ca6e65ce93160156f60292b6032b1603a7c6083e760a3e360a4b760e327645601" +
         "6466b3646e97647002687724687ff068ddb768ff7b6c4cbc6c5ab06cb1586ce873704f577405a574398974da8874ea3a" +
         "74fece7820517844fd78605b788cb578a1067c8bca7cb59b7cc2c67cf17e803c04808917808f1d80ae5480ea078416f9" +
         "84b89084d81b8825938899868c210a8c86dd8c902d8ca6df901f94909a4a90ae1b90f652940c6d94d9b394ef5098038e" +
         "98254a9848279897cc98ba5f98dac498ded09c216a9c47829c53229ca2f49ca615a0f3c1a41a3aa42bb0a8154da82948" +
         "a829dca842a1a8574ea86e84ac15a2ac84c6aca7f1b01921b0487ab04e26b09575b0958eb0a7b9b0be76b45bd1b4b024" +
         "b4c0c3b8f883b8fbb3bc071dbc4699bcd177c006c3c025e9c03a55c04a00c06118c0c9e3c0e42dc46e1fc47154c4e984" +
         "cc08fbcc32e5cc3429cc68b6ccbabdd03745d076e7d0c7c0d4016dd46e0ed4d6dfd807b6d80d17d8150dd84489d84732" +
         "d85d4cd8f12edc0077dc6279dcfe18e005c5e0280ae0d362e443cfe4c32ae4d332e4fac4e848b8e894f6e8de27ec086b" +
         "ec172fec26caec6073ec750cec888fecb931f0090df0a731f0f336f42a7df46d2ff483cdf4848df4ec38f4f26df4f50b" +
         "f81a67f86fb0f88c21f8c903f8ce21f8d111fcd733"
        ),
        ("ASUS",
         "00040f0005fc000c6e000ea600112f0011d80013d40015f20017310018f3001a83001a92001bfc001d60001e8c001fc6" +
         "00221500235400248c00261800e01804421a04922604d4c404d9f508606e08626608bfb80c9d92107b44107c6110bf48" +
         "10c37b14dae914dda91831bf1c872c1cb72c20cf30244bfe2c4d542c56dc2cfda1305a3a3085a930c5993497f6382c4a" +
         "38d5473c7c3f40167e40b076485b394cedfb50465d50ebf65404a654a0505811226045cb60a44c60cf84704d7b708bcd" +
         "74d02b7824af7c10c988d7f690e6ba9c5c8ea036bca0ad9fa85e45ac220bac9e17b06ebfb082e2bcaec5bcbf2ebcee7b" +
         "bcfce7c86000c87f54cc28aad017c2d45d64d850e6e03f49e0cb4ee89c25f02f74f07959f46d04f832e4fc3497fcc233"
        ),
        ("D-Link",
         "00055d000d88000f3d0011950013460015e900179a00195b001b11001cf0001e580021910022b000240100265a0050ba" +
         "0080c800ad2404bad6085a110c0e760cb6d21062eb10bef514d64d180f761c5f2b1c7ee51caff71cbdb928107b283b82" +
         "34029c340804340a333c1e043c33324086cb409bcd48ee0c54b80a58d56e5cd99860634c6429436c198f6c72207062b8" +
         "74dada78321b78542e7898e880268984c9b28876b9908d789094e49cd643a09f7aa0a3f0a0ab1ba42a95a8637dacf1df" +
         "b0c554b437d8b8a386bc0f9abc2228bcf685c0a0bbc412f5c4a81dc4e90ac8787dc8be19c8d3a3ccb255d032c3d8fee3" +
         "dceae7e01cfce46f13e8cc18ec2280ecade0f07d68f0b4d2f48cebf8e903fc7516"
        ),
        ("Linksys",
         "00045a000625000c41000e08000f660011500012170013100014bf0016b600173f0018390018f8001a70001c10001cdf" +
         "001d7e001ee500212900226b00227500236900259c0030bd08863b14918220aa4b24f5a230230348f8b3586d8f58ef68" +
         "6038e0687f7474121380691a94103e94445298fc11b4750ec05627c0c1c0c4411ec8b373c8d719d8ec5ee89f80ec1a59"
        ),
        ("Ubiquiti",
         "00156d0027220418d60cea1418e8291c0b8b1c6a1b245a4c24a43c28704e2ce5bd44d9e758d61f602232682e3c687251" +
         "68d79a6c63f870a7417483c274acb974f92c74fa29784558788a20802aa88478488c30668cede19041b2942a6f9c05d6" +
         "a4f8ffa89c6cac8ba9b4fbe4cc35d9d021f9d489c1d8b370d8c262dc9fdbe063dae43883f09fc2f492bff4e2c6fcecda"
        ),
        ("Synology",
         "0011329009d0"
        ),
    ]
}
