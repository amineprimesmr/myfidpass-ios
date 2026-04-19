//
//  BodyScanVideoPlayerView.swift
//  Process
//
//  Vue pour afficher une vidéo body scan
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit
import Combine

class BodyScanVideoPlayerManager: ObservableObject {
    @Published var isReady = false
    private var player: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var endTimeObserver: NSObjectProtocol?

    func setupPlayer(videoName: String) -> AVPlayer? {
        var videoURL: URL?

        // Essayer plusieurs méthodes pour trouver la vidéo
        if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            videoURL = url
        } else if let url = Bundle.main.url(forResource: videoName, withExtension: "mov") {
            videoURL = url
        } else if let url = Bundle.main.url(forResource: videoName, withExtension: nil) {
            videoURL = url
        }

        guard let finalURL = videoURL else {
            Logger.error("Vidéo body scan introuvable: \(videoName)", category: "BodyScan")
            return nil
        }

        Logger.success("Vidéo body scan chargée: \(finalURL)", category: "BodyScan")

        let playerItem = AVPlayerItem(url: finalURL)
        player = AVPlayer(playerItem: playerItem)

        // Configuration pour lecture automatique sans contrôles
        player?.isMuted = true
        player?.actionAtItemEnd = .none
        player?.allowsExternalPlayback = false

        // Observer le statut de chargement et lancer automatiquement
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                DispatchQueue.main.async {
                    if status == .readyToPlay {
                        self?.isReady = true
                        // ✅ Lancer automatiquement la vidéo
                        self?.player?.play()
                    }
                }
            }
            .store(in: &cancellables)

        // Loop la vidéo en silence
        endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        return player
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    deinit {
        if let observer = endTimeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

struct BodyScanVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let screenSize: CGSize

    func makeUIViewController(context: Context) -> BodyScanVideoPlayerViewController {
        let controller = BodyScanVideoPlayerViewController()
        controller.player = player
        controller.screenSize = screenSize
        return controller
    }

    func updateUIViewController(_ uiViewController: BodyScanVideoPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.screenSize = screenSize
        uiViewController.updateVideoLayer()
    }
}

class BodyScanVideoPlayerViewController: UIViewController {
    var player: AVPlayer? {
        didSet {
            setupPlayerLayer()
        }
    }
    var screenSize: CGSize = .zero
    private var playerLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = false
        setupPlayerLayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateVideoLayerFrame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateVideoLayerFrame()
    }

    private func setupPlayerLayer() {
        playerLayer?.removeFromSuperlayer()

        guard let player = player else { return }

        let screenBounds = UIScreen.main.bounds
        let fullFrame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)

        let newLayer = AVPlayerLayer(player: player)
        newLayer.videoGravity = .resizeAspectFill
        newLayer.frame = fullFrame
        view.layer.insertSublayer(newLayer, at: 0)
        playerLayer = newLayer

        DispatchQueue.main.async { [weak self] in
            self?.updateVideoLayerFrame()
        }
    }

    func updateVideoLayer() {
        setupPlayerLayer()
    }

    private func updateVideoLayerFrame() {
        let screenBounds = UIScreen.main.bounds
        let fullFrame = CGRect(x: 0, y: 0, width: screenBounds.width, height: screenBounds.height)

        playerLayer?.frame = fullFrame
        playerLayer?.videoGravity = .resizeAspectFill

        view.frame = fullFrame
        view.bounds = fullFrame
    }
}
