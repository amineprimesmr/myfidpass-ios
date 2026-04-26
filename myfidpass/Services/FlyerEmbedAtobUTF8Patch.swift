//
//  FlyerEmbedAtobUTF8Patch.swift
//  myfidpass
//
//  Le module en ligne (flyerEmbed-*.js) sur myfidpass.fr contient : JSON.parse(atob(t)) où t est le base64
//  du **JSON encodé en octets UTF-8** côté Swift. `atob` en JS interprète le résultat comme une « binary string »
//  (1 code unit = 1 octet), pas du texte Unicode : dès qu’un texte d’état (headline, étapes, etc.) comporte des
//  caractères non ASCII, le parse casse et `flyer_prefs` vaut null → aperçu blanc (on croyait tort à l’injection
//  / au poids du `custom_bg`). Ici on réécrit `atob` pour reconstituer d’abord les octets puis `TextDecoder` UTF-8.
//

import WebKit

enum FlyerEmbedAtobUTF8Patch {
    private static let scriptSource: String = """
    (function(){
    var n = globalThis.atob;
    if (typeof n !== 'function') { return; }
    globalThis.atob = function(s) {
    var bin = n(s);
    var len = bin.length;
    if (len === 0) { return bin; }
    var u8 = new Uint8Array(len);
    for (var i = 0; i < len; i++) { u8[i] = bin.charCodeAt(i) & 0xff; }
    try {
    return new TextDecoder('utf-8', { fatal: false, ignoreBOM: true }).decode(u8);
    } catch (e) {
    return bin;
    }
    };
    })();
    """

    static let userScript: WKUserScript = WKUserScript(
        source: scriptSource,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    static func addTo(_ configuration: WKWebViewConfiguration) {
        configuration.userContentController.addUserScript(userScript)
    }
}
