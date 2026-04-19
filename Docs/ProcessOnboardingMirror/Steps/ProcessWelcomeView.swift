//
//  ProcessWelcomeView.swift
//  Process
//
//  Page de bienvenue après le paiement - Vidéo lightspeed en fond d'écran
//

import SwiftUI
import AVKit
import AVFoundation

struct ProcessWelcomeView: View {
    @StateObject private var hapticManager = HapticManager.shared
    @State private var player: AVPlayer?
    @State private var videoEnded = false
    @State private var showBlackFade = false
    @State private var showTitleContent = false
    @State private var titleTextOpacity: Double = 0
    @State private var titleImageOpacity: Double = 0
    @State private var titleTextOffset: CGFloat = 30
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 30

    var onComplete: () -> Void
    var onBack: (() -> Void)?

    var body: some View {
        ZStack {
            // Vidéo lightspeed en fond d'écran - Plein écran, sans contrôles
            if let player = player, !videoEnded {
                ProcessWelcomeVideoPlayerViewController(player: player)
                    .ignoresSafeArea(.all)
                    .opacity(showBlackFade ? 0 : 1)
            } else {
                // Placeholder pendant le chargement ou après la vidéo
                Color.black
                    .ignoresSafeArea(.all)
            }

            // ✅ Écran noir en fondu après la vidéo
            if showBlackFade {
                Color.black
                    .ignoresSafeArea(.all)
                    .opacity(showBlackFade ? 1 : 0)
            }

            // ✅ Contenu avec image title et texte "Bienvenue dans"
            if showTitleContent {
            VStack(spacing: 0) {
                Spacer()

                    // Texte "Bienvenue dans" avec animation
                    Text("Bienvenue dans")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(titleTextOpacity)
                        .offset(y: titleTextOffset)

                Spacer()
                        .frame(height: 40)

                    // Image title
                    Image("title")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 200)
                        .padding(.horizontal, 40)
                        .opacity(titleImageOpacity)

                    Spacer()

                    // ✅ Bouton "Commencer" Liquid Glass en bas
                    Button(action: {
                        hapticManager.impact(.medium)
                        hapticManager.notification(.success)
                        // Accéder directement à l'application Process
                        onComplete()
                    }) {
                        Text("Commencer")
                            .font(.system(size: 20, weight: .black))
                                .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                    .opacity(buttonOpacity)
                    .offset(y: buttonOffset)
                }
            }
        }
        .ignoresSafeArea(.all)
        .overlay(alignment: .topLeading) {
            // ✅ BOUTON RETOUR TEMPORAIRE EN MODE DEBUG
            #if DEBUG
            if let onBack = onBack {
                    Button(action: {
                    hapticManager.impact(.light)
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                    }
                .glassStyle()
                .buttonBorderShape(.circle)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .zIndex(1000)
            }
            #endif
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        // ✅ Détecter la fin de la vidéo pour afficher le fondu et le contenu
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            // Quand la vidéo se termine, afficher le fondu puis le contenu
            handleVideoEnded()
        }
    }

    // MARK: - Video Setup

    private func setupVideo() {
        // Chercher la vidéo lightspeed.mp4
        var videoURL: URL?

        if let url = Bundle.main.url(forResource: "lightspeed", withExtension: "mp4") {
            videoURL = url
        } else if let path = Bundle.main.path(forResource: "lightspeed", ofType: "mp4") {
            videoURL = URL(fileURLWithPath: path)
        }

        guard let finalURL = videoURL else {
            Logger.error("Vidéo lightspeed.mp4 introuvable", category: "ProcessWelcome")
            // Si la vidéo n'existe pas, continuer directement après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
            return
        }

        Logger.success("✅ Vidéo lightspeed chargée: \(finalURL)", category: "ProcessWelcome")

        // Créer le player
        let playerItem = AVPlayerItem(url: finalURL)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // Configuration : pas de pause à la fin, juste rester sur la dernière frame
        avPlayer.actionAtItemEnd = .none

        // Observer la fin pour continuer automatiquement
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            Logger.debug("Vidéo lightspeed terminée - Passage à la suite", category: "ProcessWelcome")
            // onComplete() sera appelé par .onReceive
        }

        // Vidéo silencieuse
        avPlayer.isMuted = true
        avPlayer.volume = 0

        self.player = avPlayer

        // ✅ Lancer automatiquement
        avPlayer.play()

        Logger.success("✅ Vidéo lightspeed démarrée automatiquement", category: "ProcessWelcome")
    }

    // MARK: - Video End Handler

    private func handleVideoEnded() {
        hapticManager.impact(.light)
        videoEnded = true

        // ✅ Fondu rapide vers le noir
        withAnimation(.easeInOut(duration: 0.5)) {
            showBlackFade = true
        }

        // ✅ Afficher le contenu (image + texte) après le fondu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showTitleContent = true

            // ✅ Animation d'apparition du texte "Bienvenue dans"
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                titleTextOpacity = 1.0
                titleTextOffset = 0
            }

            // ✅ Animation d'apparition de l'image title
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                titleImageOpacity = 1.0
            }

            // ✅ Animation d'apparition du bouton "Commencer" après le texte et l'image
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
                buttonOpacity = 1.0
                buttonOffset = 0
            }
        }
    }
}

// MARK: - ProcessWelcomeVideoPlayer (SANS contrôles, plein écran avec UIViewController)

struct ProcessWelcomeVideoPlayerViewController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> ProcessWelcomeVideoViewController {
        let controller = ProcessWelcomeVideoViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ uiViewController: ProcessWelcomeVideoViewController, context: Context) {
        uiViewController.player = player
        uiViewController.updateVideoLayer()
    }
}

class ProcessWelcomeVideoViewController: UIViewController {
    var player: AVPlayer? {
        didSet {
            setupPlayerLayer()
        }
    }

    private var playerLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = false // ✅ Ne pas couper pour remplir tout l'écran

        // ✅ FORCER à ignorer les safe areas pour remplir vraiment tout l'écran
        if #available(iOS 11.0, *) {
            additionalSafeAreaInsets = .zero
        }

        // ✅ Utiliser la taille complète de l'écran (y compris les safe areas)
        let screenBounds = UIScreen.main.bounds
        view.frame = screenBounds
        view.bounds = screenBounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        setupPlayerLayer()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // ✅ Forcer le frame à prendre tout l'écran avant le layout
        let screenBounds = UIScreen.main.bounds
        view.frame = screenBounds
        view.bounds = screenBounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // ✅ Forcer le frame à prendre tout l'écran après le layout
        let screenBounds = UIScreen.main.bounds
        view.frame = screenBounds
        view.bounds = screenBounds
        updateVideoLayerFrame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ✅ Forcer le frame à prendre tout l'écran quand la vue apparaît
        let screenBounds = UIScreen.main.bounds
        view.frame = screenBounds
        view.bounds = screenBounds
        updateVideoLayerFrame()
                                }

    private func setupPlayerLayer() {
        // Supprimer l'ancien layer s'il existe
        playerLayer?.removeFromSuperlayer()

        guard let player = player else { return }

        // ✅ Utiliser la taille complète de l'écran (y compris les safe areas et Dynamic Island)
        let screenBounds = UIScreen.main.bounds
        // ✅ CRITIQUE: Utiliser des coordonnées négatives si nécessaire pour vraiment tout couvrir
        let fullFrame = CGRect(
            x: -view.safeAreaInsets.left,
            y: -view.safeAreaInsets.top,
            width: screenBounds.width + view.safeAreaInsets.left + view.safeAreaInsets.right,
            height: screenBounds.height + view.safeAreaInsets.top + view.safeAreaInsets.bottom
        )

        let newLayer = AVPlayerLayer(player: player)
        newLayer.videoGravity = .resizeAspectFill
        // ✅ Utiliser UIScreen.main.bounds directement pour être sûr
        newLayer.frame = UIScreen.main.bounds
        view.layer.insertSublayer(newLayer, at: 0)
        playerLayer = newLayer

        // Mettre à jour le frame immédiatement
        DispatchQueue.main.async { [weak self] in
            self?.updateVideoLayerFrame()
        }
    }

    func updateVideoLayer() {
        setupPlayerLayer()
    }

    private func updateVideoLayerFrame() {
        // ✅ Utiliser UIScreen.main.bounds directement pour vraiment tout couvrir
        let screenBounds = UIScreen.main.bounds
        let fullFrame = CGRect(
            x: 0,
            y: 0,
            width: screenBounds.width,
            height: screenBounds.height
        )

        // ✅ Forcer la vue à prendre tout l'écran
        view.frame = screenBounds
        view.bounds = screenBounds

        // ✅ CRITIQUE: Utiliser screenBounds directement pour le layer, pas view.bounds
        playerLayer?.frame = screenBounds
        playerLayer?.videoGravity = .resizeAspectFill
}
}
