//
//  DashboardViewSupport.swift
//  myfidpass — routes et composants accueil (extrait de DashboardView.swift)
//

import SwiftUI
import UIKit

enum DashboardRoute: Hashable {
    case membersActivity(MemberActivityFilter)
}

enum HomeMyCardZoom {
    static let previewSourceID = "dashboard.home.mycard.preview"
}

enum DashboardHomeChrome {
    static let showMinimalTopBar = true
}

struct DashboardHomeSetupEmptyCardPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.0),
                        Color(red: 0.90, green: 0.92, blue: 0.96),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(1.78, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        Color(red: 0.72, green: 0.76, blue: 0.86).opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
            .overlay {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color(red: 0.52, green: 0.58, blue: 0.72).opacity(0.5))
            }
    }
}

struct DashboardSetupHeroCarousel: View {
    enum HeroVisualKind: Equatable {
        case loyaltyCardIsoId1
        case flyerPortrait9x16
    }

    let kind: HeroVisualKind
    let imageNames: [String]
    var fallbackImage: UIImage? = nil

    private var heroSlotSize: CGSize {
        switch kind {
        case .loyaltyCardIsoId1:
            let w: CGFloat = 86
            let h = w * (16.0 / 9.0)
            return CGSize(width: w, height: h)
        case .flyerPortrait9x16:
            let h: CGFloat = 140
            let w = h * (9.0 / 16.0)
            return CGSize(width: w, height: h)
        }
    }

    private var stackViewport: CGSize {
        let slot = heroSlotSize
        switch kind {
        case .loyaltyCardIsoId1:
            return CGSize(width: max(148, slot.width + 28), height: max(168, slot.height + 24))
        case .flyerPortrait9x16:
            return CGSize(width: max(118, slot.width + 36), height: max(158, slot.height + 22))
        }
    }

    var body: some View {
        let slot = heroSlotSize
        let viewport = stackViewport
        TimelineView(.periodic(from: .now, by: 2.7)) { timeline in
            let count = max(imageNames.count, 1)
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 2.7)
            let active = ((tick % count) + count) % count

            ZStack {
                ForEach(imageNames.indices, id: \.self) { index in
                    let rank = ((index - active) % count + count) % count
                    carouselCard(for: imageNames[index])
                        .frame(width: slot.width, height: slot.height)
                        .clipShape(RoundedRectangle(cornerRadius: heroClipCornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.38), radius: 14, y: 8)
                        .scaleEffect(rank == 0 ? 1.0 : (rank == 1 ? 0.94 : 0.89))
                        .rotationEffect(.degrees(fanRotationDegrees(rank: rank)))
                        .offset(x: fanOffsetX(rank: rank), y: fanOffsetY(rank: rank))
                        .opacity(rank == 0 ? 1.0 : (rank == 1 ? 0.88 : 0.72))
                        .zIndex(Double(100 - rank))
                        .animation(.spring(response: 0.44, dampingFraction: 0.9), value: active)
                }
            }
            .frame(width: viewport.width, height: viewport.height, alignment: .center)
        }
    }

    private var heroClipCornerRadius: CGFloat {
        switch kind {
        case .flyerPortrait9x16: return 10
        case .loyaltyCardIsoId1: return 14
        }
    }

    private func fanRotationDegrees(rank: Int) -> Double {
        switch kind {
        case .loyaltyCardIsoId1:
            return rank == 0 ? -4 : (rank == 1 ? 6 : 10)
        case .flyerPortrait9x16:
            return rank == 0 ? -3 : (rank == 1 ? 5 : 8)
        }
    }

    private func fanOffsetX(rank: Int) -> CGFloat {
        switch kind {
        case .loyaltyCardIsoId1:
            return rank == 0 ? 0 : (rank == 1 ? 20 : 36)
        case .flyerPortrait9x16:
            return rank == 0 ? 0 : (rank == 1 ? 10 : 20)
        }
    }

    private func fanOffsetY(rank: Int) -> CGFloat {
        switch kind {
        case .loyaltyCardIsoId1:
            return rank == 0 ? 0 : (rank == 1 ? -4 : -7)
        case .flyerPortrait9x16:
            return rank == 0 ? 0 : (rank == 1 ? -3 : -5)
        }
    }

    @ViewBuilder
    private func carouselCard(for name: String) -> some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: kind == .loyaltyCardIsoId1 ? .fit : .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    kind == .loyaltyCardIsoId1
                        ? Color.black.opacity(0.2)
                        : Color.clear
                )
        } else if let fallbackImage {
            Image(uiImage: fallbackImage)
                .resizable()
                .aspectRatio(contentMode: kind == .loyaltyCardIsoId1 ? .fit : .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.17, green: 0.24, blue: 0.35),
                    Color(red: 0.09, green: 0.13, blue: 0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct HomeSetupGlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.15, blue: 0.18),
                        Color(red: 0.05, green: 0.06, blue: 0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.46), lineWidth: 1.35)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }
}

struct MerchantHomeFlyerPromoSheetContext: Identifiable, Equatable {
    let id = UUID()
    let businessSlug: String

    static func == (lhs: MerchantHomeFlyerPromoSheetContext, rhs: MerchantHomeFlyerPromoSheetContext) -> Bool {
        lhs.id == rhs.id && lhs.businessSlug == rhs.businessSlug
    }
}
