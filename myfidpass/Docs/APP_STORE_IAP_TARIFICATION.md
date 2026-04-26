# Abonnement commerçant in-app — aligné site (Stripe) avril 2026

## Offre cible (même règles : app + web)

| Période | Facturation **mensuelle** (App Store) | Facturation **annuelle** (App Store) | Site (Stripe) |
|--------|----------------------------------------|----------------------------------------|----------------|
| 1) Essai | **3 j** gratuits | **3 j** gratuits | **3 j** (`STRIPE_SUBSCRIPTION_TRIAL_DAYS`) + essai compte 3 j (`MERCHANT_TRIAL_DAYS` défaut) |
| 2) 1ʳ période payante | 1,00 € le 1er mois | **—** (pas de 1 € : facturation 399,00 €/an) | Mensuel : coupon **1er mois à 1,00 €** (voir `STRIPE_COUPON_ID_FIRST_MONTH_1_EUR`) + prix 49,99 €. Annuel : 399,00 €/an |
| 3) Renouvellement | 49,99 € / mois, sans engagement | 399,00 € / an | Identique via `price_…` Stripe |

## Contrainte Apple (rappel)

Sur **un** produit d’abonnement auto-renouvelable, Apple n’expose en général **qu’une** offre introductive « signée » par version de produit (essai gratuit, tarif introductif payant, etc.). L’enchaînement théorique *« 3 j gratuits + 1re période à 1,00 € + 49,99 »* n’est donc **pas** toujours reproductible en trois paliers indépendants sur **le même** SKU, selon la fiche d’abonnement du groupe en App Store Connect.

**Pratique côté app :**  
- Même discours produit (voir `MerchantSubscriptionPricingCopy` + `CustomMerchantProPaywallView`).  
- Côté App Store Connect, viser l’**approche la plus proche** : p.ex. **essai 3 j** + renouvellement, **ou** 1,00 € la 1re période payante + 49,99, selon ce qu’autorise la fiche, puis **synchroniser** les durées / montants avec le code et RevenueCat.

Même principe pour l’**annuel** : **3 j d’essai** puis **399,00 € / an** (l’app ne doit plus parler de 14 j pour l’annuel).

## RevenueCat

Offre **default** : packages **mensuel** + **annuel** reliés aux product IDs, tarifs en EUR (France) alignés 49,99 / 399,00.

Voir aussi `REVENUECAT_SETUP.md` pour les clés et l’entitlement `myfidpass_premium`.
