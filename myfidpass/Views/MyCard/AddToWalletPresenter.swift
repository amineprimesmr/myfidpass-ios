//
//  AddToWalletPresenter.swift
//  myfidpass
//
//  Présente la feuille Apple « Ajouter à l’Apple Wallet » à partir des données d’un pass (.pkpass).
//

import SwiftUI
import PassKit

/// Présente `PKAddPassesViewController` lorsque des données de pass sont fournies.
struct AddToWalletPresenter: UIViewControllerRepresentable {
    let passData: Data?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if passData == nil {
            context.coordinator.didPresentForCurrentData = false
            return
        }
        if context.coordinator.didPresentForCurrentData { return }
        guard let data = passData, !data.isEmpty else { return }
        guard PKAddPassesViewController.canAddPasses() else {
            onDismiss()
            return
        }
        guard let pass = try? PKPass(data: data) else {
            onDismiss()
            return
        }
        guard let addVC = PKAddPassesViewController(pass: pass) else {
            onDismiss()
            return
        }
        addVC.delegate = context.coordinator
        addVC.modalPresentationStyle = .formSheet
        if uiViewController.presentedViewController == nil {
            context.coordinator.didPresentForCurrentData = true
            uiViewController.present(addVC, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        var onDismiss: () -> Void
        var didPresentForCurrentData = false

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.presentingViewController?.dismiss(animated: true)
            didPresentForCurrentData = false
            onDismiss()
        }
    }
}
