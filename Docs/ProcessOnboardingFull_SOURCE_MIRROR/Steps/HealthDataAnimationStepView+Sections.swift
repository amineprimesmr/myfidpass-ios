//
//  HealthDataAnimationStepView+Sections.swift
//  Process
//
//  Sections UI « Sources de données » et « Aujourd'hui » — extrait de HealthDataAnimationStepView.
//

import SwiftUI
import FirebaseAuth
import HealthKit

extension HealthDataAnimationStepView {
    // ✨ Section Sources de données avec 2 sous-parties
    var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ✨ Mode compact : sources côte à côte dans le même fond gris
            // Vérifier que toutes les animations sont terminées
            let allDataTypesCompleted = completedDataTypes.count == healthDataTypes.count
            // ✅ CORRECTION: Vérifier toutes les sources réelles (pas seulement defaultHealthSources)
            // Limiter à 10 sources pour la vérification
            let sourcesToCheck = Array(realDataSources.prefix(10))
            let allHealthSourcesCompleted = sourcesToCheck.isEmpty ? false : completedHealthSources.count >= min(sourcesToCheck.count, 10)
            // ✨ Vérifier que "Mouvement du téléphone" est complété
            let phoneMovementCompleted = phoneMovementProgress >= 1.0
            // ✨ Vérifier que "Santé Apple" est complété
            let appleHealthCompleted = appleHealthProgress >= 1.0

            if allDataTypesCompleted && allHealthSourcesCompleted && phoneMovementCompleted && appleHealthCompleted && sourcesAnimationComplete {
                // ✨ Mode compact : titre et sources dans le même fond gris
                VStack(alignment: .leading, spacing: 16) {
                    // Titre (sans fond séparé)
                    HStack {
                        Text("Sources de données")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
            Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // Sources en compact (plus petites, dans des badges verts individuels avec flèches)
                    // ✅ CORRECTION: Afficher TOUTES les sources trouvées dans realDataSources (pas seulement defaultHealthSources)
                    // Limiter à 10 sources max pour l'affichage (trop de sources rendrait l'UI illisible)
                    let compactSources = Array(realDataSources.prefix(10))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(compactSources.enumerated()), id: \.offset) { index, source in
                                HStack(spacing: 6) {
                                    Text(source)
                                        .font(.system(size: 14, weight: .medium)) // Plus petit
                    .foregroundColor(.white)

                                    // Flèche double à droite de chaque source (sauf le dernier)
                                    if index < compactSources.count - 1 {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.system(size: 11, weight: .medium)) // Plus petit
                                            .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.2))
                                )
                                .transition(.scale(scale: 0.8).combined(with: .opacity)) // ✨ Animation de scale plus visible
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                )
                .padding(.horizontal, -20) // ✨ Annuler le padding du VStack parent pour que le fond prenne toute la largeur
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.75)),
                    removal: .move(edge: .top).combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.75))
                )) // ✨ Animation fluide de rétraction
            } else {
                // Mode animation : 2 sous-parties
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Sources de données")
                            .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                    )

                    // Contenu de la section (apparaît progressivement)
                    if showSourcesContent {
                        VStack(alignment: .leading, spacing: 20) {
                            // ✨ Sous-partie 1 : Mouvement du téléphone
                            phoneMovementSubsection

                            // ✨ Séparateur
                            Divider()
                                .background(Color.white.opacity(0.1))

                            // ✨ Sous-partie 2 : Santé Apple
                            appleHealthSubsection
                        }
                    }
                }
            }
        }
    }

    // ✨ Sous-partie : Mouvement du téléphone
    private var phoneMovementSubsection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icône téléphone avec Zz (comme dans l'image)
                ZStack {
                    Image(systemName: "iphone")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Text("Zz")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(x: 10, y: -10)
                }
                .frame(width: 24, height: 24)

                Text("Mouvement du téléphone")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // ✨ Checkmark vert si complété, sinon barre de progression
                if phoneMovementProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                } else {
                    // Barre de progression améliorée avec animation fluide
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Fond gris avec rayures animées
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                                .overlay(
                                    // Rayures diagonales animées pour la partie non remplie
                                    Path { path in
                                        let stripeWidth: CGFloat = 4
                                        var x: CGFloat = geometry.size.width * phoneMovementProgress
                                        while x < geometry.size.width {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + stripeWidth, y: 8))
                                            x += stripeWidth * 2
                                        }
                                    }
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )

                            // Partie remplie avec animation fluide et gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * phoneMovementProgress, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: phoneMovementProgress)
                        }
                    }
                    .frame(width: 100, height: 8)
                }
            }
        }
    }

    // ✨ Sous-partie : Santé Apple
    private var appleHealthSubsection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titre avec barre de progression
            HStack(spacing: 12) {
                // Image healthapple
                Image("healthapple")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Text("Santé Apple")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // ✨ Checkmark vert si complété, sinon barre de progression
                if appleHealthProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                } else {
                    // Barre de progression améliorée avec animation fluide
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Fond gris avec rayures animées
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                                .overlay(
                                    // Rayures diagonales animées pour la partie non remplie
                                    Path { path in
                                        let stripeWidth: CGFloat = 4
                                        var x: CGFloat = geometry.size.width * appleHealthProgress
                                        while x < geometry.size.width {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + stripeWidth, y: 8))
                                            x += stripeWidth * 2
                                        }
                                    }
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )

                            // Partie remplie avec animation fluide et gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * appleHealthProgress, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appleHealthProgress)
                        }
                    }
                    .frame(width: 100, height: 8)
                }
            }

            // Types de données (Les étapes, Minutes d'exercice, etc.)
            VStack(spacing: 12) {
                ForEach(healthDataTypes, id: \.self) { dataType in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(completedDataTypes.contains(dataType) ? Color(red: 0.13, green: 0.98, blue: 0.47) : .white.opacity(0.3))

                        Text(dataType)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Sources - Afficher TOUTES les sources réelles trouvées (pas seulement defaultHealthSources)
            VStack(spacing: 12) {
                ForEach(Array(realDataSources.prefix(10)), id: \.self) { source in
                    // Cette source est forcément réelle puisqu'on l'a filtrée
                    HStack(spacing: 12) {
                        // ✨ Afficher un ProgressView si en chargement, sinon checkmark
                        if loadingHealthSources.contains(source) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.13, green: 0.98, blue: 0.47)))
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(
                                    completedHealthSources.contains(source) ?
                                    Color(red: 0.13, green: 0.98, blue: 0.47) : // Vert si complété
                                    .white.opacity(0.3) // Gris si pas complété
                                )
                        }

                        Text(source)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(
                                completedHealthSources.contains(source) ?
                                .white.opacity(0.9) : // Blanc si complété
                                .white.opacity(0.5) // Gris si pas complété
                            )

                        Spacer()

                        // Flèche double si complété
                        if completedHealthSources.contains(source) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                        }
                    }
                    .padding(.horizontal, completedHealthSources.contains(source) ? 12 : 0)
                    .padding(.vertical, completedHealthSources.contains(source) ? 8 : 0)
                    .background(
                        completedHealthSources.contains(source) ?
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.2)) :
                        nil
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // ✨ Données de sommeil sous "Aujourd'hui" (anciennement "Patterns de sommeil", maintenant "Besoin de sommeil") - dynamiques avec valeurs réelles

    // ✨ Section Aujourd'hui avec 2 sous-parties (toujours visible, ne se ferme jamais)
    var myViewpointSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ✨ Mode animation : toujours affiché, ne passe jamais en mode compact
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Aujourd'hui")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        // ✨ Compteur dans un rectangle noir (comme l'image)
                        HStack(spacing: 4) {
                            Text("\(daysFound)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .contentTransition(.numericText()) // ✨ Animation fluide du compteur

                            Text("JOURS TROUVÉS")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                )

                // Contenu de la section (apparaît progressivement)
                if showMyViewpointContent {
                    VStack(alignment: .leading, spacing: 20) {
                        // ✨ Sous-partie 1 : Besoin de sommeil (anciennement "Patterns de sommeil")
                        sleepPatternSubsection

                        // ✨ Sections DATA intégrées (apparaissent en même temps)
                        if showDataSection {
                            // ✨ Séparateur
                            Divider()
                                .background(Color.white.opacity(0.1))

                            // ✨ Sous-partie 2 : Récupération (anciennement "Besoin de sommeil")
                            sleepNeedSubsection

                            // ✨ Séparateur
                            Divider()
                                .background(Color.white.opacity(0.1))

                            // ✨ Sous-partie 3 : Capacité d'entrainement (anciennement "Dette de sommeil")
                            sleepDebtSubsection
                        }
                    }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.75)),
            removal: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.8, dampingFraction: 0.75))
        )) // ✨ Animation fluide de montée depuis le bas
    }

    // ✨ Sous-partie : Patterns de sommeil
    private var sleepPatternSubsection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titre avec barre de progression
            HStack(spacing: 12) {
                // Image luneicone
                Image("luneicone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text("Récupération")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // ✨ Checkmark vert si complété, sinon barre de progression
                if sleepPatternProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                    } else {
                    // Barre de progression améliorée avec animation fluide
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Fond gris avec rayures animées
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                                .overlay(
                                    // Rayures diagonales animées pour la partie non remplie
                                    Path { path in
                                        let stripeWidth: CGFloat = 4
                                        var x: CGFloat = geometry.size.width * sleepPatternProgress
                                        while x < geometry.size.width {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + stripeWidth, y: 8))
                                            x += stripeWidth * 2
                                        }
                                    }
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )

                            // Partie remplie avec animation fluide et gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * sleepPatternProgress, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sleepPatternProgress)
                        }
                    }
                    .frame(width: 100, height: 8)
                }
            }

            // Types de données (Heures de coucher, Durée de sommeil, etc.)
            VStack(spacing: 12) {
                ForEach(getSleepPatternTypes(), id: \.self) { dataType in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(completedSleepPattern.contains(dataType) ? Color(red: 0.13, green: 0.98, blue: 0.47) : .white.opacity(0.3))

                        Text(dataType)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // ✨ Sous-partie : Besoin de sommeil
    private var sleepNeedSubsection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titre avec barre de progression
            HStack(spacing: 12) {
                // Image luneicone
                Image("luneicone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Text("Récupération")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // ✨ Checkmark vert si complété, sinon barre de progression
                if sleepNeedProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                    } else {
                    // Barre de progression améliorée avec animation fluide
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Fond gris avec rayures animées
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                                .overlay(
                                    // Rayures diagonales animées pour la partie non remplie
                                    Path { path in
                                        let stripeWidth: CGFloat = 4
                                        var x: CGFloat = geometry.size.width * sleepNeedProgress
                                        while x < geometry.size.width {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + stripeWidth, y: 8))
                                            x += stripeWidth * 2
                                        }
                                    }
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )

                            // Partie remplie avec animation fluide et gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * sleepNeedProgress, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sleepNeedProgress)
                        }
                    }
                    .frame(width: 100, height: 8)
                }
            }

            // Types de données
            VStack(spacing: 12) {
                ForEach(sleepNeedTypes, id: \.self) { dataType in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(completedSleepNeed.contains(dataType) ? Color(red: 0.13, green: 0.98, blue: 0.47) : .white.opacity(0.3))

                        Text(dataType)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // ✨ Sous-partie : Dette de sommeil
    private var sleepDebtSubsection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titre avec barre de progression
            HStack(spacing: 12) {
                // Image sporticone
                Image("sporticone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Text("Capacité d'entrainement")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // ✨ Checkmark vert si complété, sinon barre de progression
                if sleepDebtProgress >= 1.0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                } else {
                    // Barre de progression améliorée avec animation fluide
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Fond gris avec rayures animées
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 8)
                                .overlay(
                                    // Rayures diagonales animées pour la partie non remplie
                                    Path { path in
                                        let stripeWidth: CGFloat = 4
                                        var x: CGFloat = geometry.size.width * sleepDebtProgress
                                        while x < geometry.size.width {
                                            path.move(to: CGPoint(x: x, y: 0))
                                            path.addLine(to: CGPoint(x: x + stripeWidth, y: 8))
                                            x += stripeWidth * 2
                                        }
                                    }
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )

                            // Partie remplie avec animation fluide et gradient
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * sleepDebtProgress, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sleepDebtProgress)
                        }
                    }
                    .frame(width: 100, height: 8)
                }
            }

            // Types de données
            VStack(spacing: 12) {
                ForEach(getSleepDebtTypes(), id: \.self) { dataType in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(completedSleepDebt.contains(dataType) ? Color(red: 0.13, green: 0.98, blue: 0.47) : .white.opacity(0.3))

                        Text(dataType)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}
