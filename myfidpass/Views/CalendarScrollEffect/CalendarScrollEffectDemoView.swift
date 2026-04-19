//
//  CalendarScrollEffectDemoView.swift
//  myfidpass
//
//  Calendrier défilant : activité commerçant par jour (même logique que l’accueil).
//

import CoreData
import SwiftUI

struct CalendarScrollEffectDemoView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CalendarScrollEffectHomeView(context: viewContext)
            .environmentObject(syncService)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .padding(.top, 8)
                .accessibilityLabel("Retour")
            }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CalendarScrollEffectDemoView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(SyncService(container: PersistenceController.preview.container))
    }
}
#endif
