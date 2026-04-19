//
//  ImageCropExportHandle.swift
//  myfidpass
//
//  Référence faible vers le coordinateur UIKit pour extraire le cadrage courant.
//

import UIKit

final class ImageCropExportHandle {
    weak var coordinator: ImageCropScrollCoordinator?

    func makeCroppedUIImage() -> UIImage? {
        coordinator?.makeCroppedUIImage()
    }
}
