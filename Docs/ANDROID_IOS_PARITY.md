# Parité iOS ↔ Android

**Source de vérité runtime (Android)** : `android/app/src/main/java/fr/myfidpass/ui/navigation/IosParityChecklist.kt`

**Doc historique** : ce fichier — ne pas dupliquer la checklist ici ; mettre à jour `IosParityChecklist.kt` lors de chaque feature.

| Domaine | iOS | Android | Notes |
|---------|-----|---------|-------|
| Auth email / Google | ✅ | ✅ | Apple iOS only |
| Dashboard + sync | ✅ | ✅ | Room + Core Data |
| Ma Carte | ✅ | ✅ | Wallet iOS / preview Android |
| Campagnes + périmètre | ✅ | ✅ | |
| Stats commerce | ✅ | ✅ | |
| Flyer / QR | ✅ | ✅ | WebView embed SaaS |
| Push | APNs | FCM | |

Stratégie produit 2026 : **commerçant = apps natives** ; web `/app` gelé (`fidelity/frontend/src/constants/merchant-product.js`).
