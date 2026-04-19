//
//  WelcomeStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct WelcomeStepView: View {

    var body: some View {
        VStack(spacing: 50) {
            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Process")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()
        }
}
}
