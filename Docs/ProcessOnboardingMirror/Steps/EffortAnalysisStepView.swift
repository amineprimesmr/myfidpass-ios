//
//  EffortAnalysisStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import FirebaseAuth
import HealthKit

struct EffortAnalysisStepView: View {

    var body: some View {
        VStack(spacing: 50) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Améliore tes performances")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("en comprenant ton")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("score d'effort")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
        }
}
}
