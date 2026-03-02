//
//  CustomHostingView.swift
//  DynamicIslandToast
//
//  Created by Balaji Venkatesh on 04/01/26.
//

import SwiftUI

class CustomHostingView: UIHostingController<ToastView> {
    var isStatusBarHidden: Bool = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return isStatusBarHidden
    }
}
