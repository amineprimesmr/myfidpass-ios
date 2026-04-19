//
//  CommitmentRow.swift
//  Process
//
//  Composant pour afficher une ligne d'engagement avec checkmark vert
//

import SwiftUI

struct CommitmentRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            // Checkmark vert
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))

            // Texte de l'engagement
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.leading)

            Spacer()
        }
}
}
