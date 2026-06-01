//
//  CustomSideMenu.swift
//  XStyleSideBar — intégré MyFidpass (Balaji Venkatesh, 08/05/26).
//

import SwiftUI
import UIKit

struct CustomSideMenu<MenuContent: View, Content: View>: View {
    var isEnabled: Bool = true
    var sideBarWidth: CGFloat = 280
    /// Remplissage du panneau coulissant (forme concentrique — aligné zip original).
    var slidingPanelFill: Color = Color(.systemBackground)
    @Binding var isExpanded: Bool
    @ViewBuilder var menuContent: (_ progress: CGFloat) -> MenuContent
    @ViewBuilder var content: (_ progress: CGFloat) -> Content

    @State private var progress: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var haptics: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if progress > 0.001 {
                Color.black
                    .ignoresSafeArea()
            }

            menuContent(progress)
                .frame(width: sideBarWidth)
                .frame(maxHeight: .infinity)
                .opacity(progress)
                .scaleEffect(0.95 + (0.05 * progress))

            content(progress)
                .containerRelativeFrame(.horizontal)
                .frame(maxHeight: .infinity)
                .background {
                    backgroundShape
                        .fill(slidingPanelFill)
                        .ignoresSafeArea()
                }
                .overlay {
                    backgroundShape
                        .fill(.fill.tertiary)
                        .stroke(.fill.secondary, lineWidth: 1)
                        .ignoresSafeArea()
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(animation) {
                                dismissMenu()
                            }
                        }
                        .opacity(progress)
                        .allowsHitTesting(progress > 0.001)
                }
                .mask {
                    backgroundShape
                        .ignoresSafeArea()
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.06 * progress), radius: 5, x: -10, y: 0)
                .offset(x: xOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            SideMenuPanGestureInstaller(
                isEnabled: isEnabled,
                isExpanded: isExpanded,
                onPan: handlePan(translation:state:velocity:)
            )
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: haptics)
        .onChange(of: isExpanded) { _, newValue in
            withAnimation(animation) {
                if newValue && progress != 1 {
                    expandMenu()
                }
                if !newValue && progress != 0 {
                    dismissMenu()
                }
            }
        }
    }

    private func handlePan(translation: CGFloat, state: UIGestureRecognizer.State, velocity: CGFloat) {
        let adjusted = translation + (isExpanded ? sideBarWidth : 0)
        switch state {
        case .began, .changed:
            xOffset = min(max(adjusted, 0), sideBarWidth)
            progress = xOffset / sideBarWidth
        case .ended, .cancelled, .failed:
            withAnimation(animation) {
                if (xOffset + velocity) > (sideBarWidth / 2) {
                    expandMenu()
                } else {
                    dismissMenu()
                }
            }
        default:
            break
        }
    }

    private func expandMenu() {
        if !isExpanded { haptics.toggle() }
        xOffset = sideBarWidth
        progress = 1
        isExpanded = true
    }

    private func dismissMenu() {
        if isExpanded { haptics.toggle() }
        xOffset = 0
        progress = 0
        isExpanded = false
    }

    private var backgroundShape: some Shape {
        MFConcentricShapeFallback(minimumCorner: 45, isUniform: true)
    }

    private var animation: Animation {
        .interactiveSpring(duration: 0.2, extraBounce: 0.02)
    }
}

// MARK: - Pan UIKit (zip original) — sur la fenêtre, `cancelsTouchesInView = false` → taps OK.

private struct SideMenuPanGestureInstaller: UIViewRepresentable {
    var isEnabled: Bool
    var isExpanded: Bool
    var onPan: (CGFloat, UIGestureRecognizer.State, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPan: onPan)
    }

    func makeUIView(context: Context) -> SideMenuPanAnchorView {
        let view = SideMenuPanAnchorView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: SideMenuPanAnchorView, context: Context) {
        context.coordinator.onPan = onPan
        context.coordinator.isExpanded = isExpanded
        context.coordinator.isEnabled = isEnabled
        uiView.attachPanIfNeeded()
    }

    static func dismantleUIView(_ uiView: SideMenuPanAnchorView, coordinator: Coordinator) {
        coordinator.detachPan()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPan: (CGFloat, UIGestureRecognizer.State, CGFloat) -> Void
        var isExpanded: Bool = false
        var isEnabled: Bool = true
        private var pan: UIPanGestureRecognizer?

        init(onPan: @escaping (CGFloat, UIGestureRecognizer.State, CGFloat) -> Void) {
            self.onPan = onPan
        }

        func attach(to window: UIWindow) {
            if pan == nil {
                let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                gesture.delegate = self
                gesture.maximumNumberOfTouches = 1
                gesture.cancelsTouchesInView = false
                gesture.delaysTouchesBegan = false
                pan = gesture
            }
            guard let pan, pan.view !== window else { return }
            pan.view?.removeGestureRecognizer(pan)
            window.addGestureRecognizer(pan)
        }

        func detachPan() {
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard isEnabled else { return }
            let translation = gesture.translation(in: gesture.view).x
            let velocity = gesture.velocity(in: gesture.view).x / 5
            onPan(translation, gesture.state, velocity)
            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                gesture.setTranslation(.zero, in: gesture.view)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled else { return false }
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            let isHorizontalSwipe = abs(velocity.x) > abs(velocity.y)
            return (isHorizontalSwipe && velocity.x > 0) || (isHorizontalSwipe && velocity.x < 0 && isExpanded)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                return scrollView.contentOffset.x <= 0
            }
            return false
        }
    }

    final class SideMenuPanAnchorView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attachPanIfNeeded()
        }

        func attachPanIfNeeded() {
            guard let window else { return }
            coordinator?.attach(to: window)
        }
    }
}
