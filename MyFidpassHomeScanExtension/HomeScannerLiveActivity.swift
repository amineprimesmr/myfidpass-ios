//
//  HomeScannerLiveActivity.swift
//  MyFidpassHomeScanExtension
//
//  Dynamic Island + écran verrouillé : raccourci « Scanner » (myfidpass://scan).
//

import ActivityKit
import SwiftUI
import WidgetKit

private let homeScanURL = URL(string: "myfidpass://scan")!

struct HomeScannerIslandWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HomeScannerActivityAttributes.self) { _ in
            LockScreenScannerCard()
                .padding(.vertical, 6)
                .activityBackgroundTint(Color.black.opacity(0.5))
                .activitySystemActionForegroundColor(Color.white)
                .widgetURL(homeScanURL)
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scanner QR")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Carte fidélité du client")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link(destination: homeScanURL) {
                            Label("Ouvrir le scanner", systemImage: "qrcode.viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color(red: 0.15, green: 0.39, blue: 0.92).opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 1))
            } compactTrailing: {
                Text("Scan")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } minimal: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 1))
            }
            .widgetURL(homeScanURL)
            .keylineTint(Color(red: 0.15, green: 0.39, blue: 0.92))
        }
    }
}

private struct LockScreenScannerCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.39, blue: 0.92),
                                Color(red: 0.35, green: 0.55, blue: 1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: "qrcode.viewfinder")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Scanner")
                    .font(.headline.weight(.bold))
                Text("Toucher pour ouvrir la caméra QR")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}
