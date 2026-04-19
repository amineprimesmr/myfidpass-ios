//
//  CalendarScrollEffectTaskRow.swift
//  myfidpass
//
//  Ligne d’activité commerçant (scan / nouvelle carte) pour le calendrier défilant.
//

import SwiftUI

struct CalendarScrollActivityRow: View {
    let entry: DashboardActivityEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private var kindLabel: String {
        switch entry.kind {
        case .scan: return "Scan fidélité"
        case .newCard: return "Nouvelle carte"
        }
    }

    private var iconName: String {
        switch entry.kind {
        case .scan: return "qrcode.viewfinder"
        case .newCard: return "person.crop.circle.badge.plus"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.clientName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(Self.timeFormatter.string(from: entry.date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
    }
}
