//
//  FlyerGiftWheelPromoOverlay.swift
//  myfidpass
//
//  L’illustration `giftflyer` est désormais dessinée dans le canvas partagé
//  (`fidelity/frontend` → `drawFlyerGiftflyerPromo` dans `app-flyer-qr-draw.js`) :
//  ordre roue → cadeau → bandeau « Scanne pour jouer ». Ce type est conservé
//  vide pour ne pas casser d’éventuelles références ; l’asset `giftflyer` peut
//  rester dans le catalogue (non utilisé par l’app).
//

import SwiftUI

@available(*, deprecated, message: "giftflyer est rendu dans le canvas web (embed).")
struct FlyerGiftWheelPromoOverlay: View {
    var body: some View {
        EmptyView()
    }
}
