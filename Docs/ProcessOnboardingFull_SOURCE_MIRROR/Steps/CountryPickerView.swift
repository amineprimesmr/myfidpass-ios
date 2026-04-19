//
//  CountryPickerView.swift
//  Process
//
//  Created by Assistant on 16/10/2025.
//

import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCountryCode: String
    @Binding var selectedCountryFlag: String
    @Binding var isPresented: Bool

    let countries = [
        ("🇫🇷", "+33", "France"),
        ("🇺🇸", "+1", "États-Unis"),
        ("🇬🇧", "+44", "Royaume-Uni"),
        ("🇩🇪", "+49", "Allemagne"),
        ("🇪🇸", "+34", "Espagne"),
        ("🇮🇹", "+39", "Italie"),
        ("🇨🇦", "+1", "Canada"),
        ("🇦🇺", "+61", "Australie"),
        ("🇯🇵", "+81", "Japon"),
        ("🇰🇷", "+82", "Corée du Sud"),
        ("🇨🇳", "+86", "Chine"),
        ("🇮🇳", "+91", "Inde"),
        ("🇧🇷", "+55", "Brésil"),
        ("🇲🇽", "+52", "Mexique"),
        ("🇷🇺", "+7", "Russie"),
        ("🇿🇦", "+27", "Afrique du Sud"),
        ("🇳🇱", "+31", "Pays-Bas"),
        ("🇧🇪", "+32", "Belgique"),
        ("🇨🇭", "+41", "Suisse"),
        ("🇦🇹", "+43", "Autriche")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(countries, id: \.1) { country in
                    Button(action: {
                        selectedCountryCode = country.1
                        selectedCountryFlag = country.0
                        isPresented = false
                    }) {
                        HStack {
                            Text(country.0)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.2)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(country.1)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedCountryCode == country.1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Sélectionner un pays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        isPresented = false
                    }
}
}
}
}
}
