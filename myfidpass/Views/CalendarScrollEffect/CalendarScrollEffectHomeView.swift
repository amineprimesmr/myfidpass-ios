//
//  CalendarScrollEffectHomeView.swift
//  myfidpass
//
//  Calendrier défilant : une section par jour de la semaine, alimentée par le même fil
//  d’activité que l’accueil (scans + nouvelles cartes), via Core Data / DataService.
//

import CoreData
import SwiftUI

struct CalendarScrollEffectHomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService

    @State private var currentWeek: [CalendarScrollDay] = Date.calendarScrollCurrentWeek
    @State private var selectedDate: Date?
    @State private var activityByDay: [Date: [DashboardActivityEntry]] = [:]
    @Namespace private var namespace

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private func reloadActivity() {
        let days = currentWeek.map(\.date)
        activityByDay = dataService.dashboardActivityGroupedByDay(includedDays: days)
    }

    private func entries(for day: CalendarScrollDay) -> [DashboardActivityEntry] {
        let key = Calendar.current.startOfDay(for: day.date)
        return activityByDay[key] ?? []
    }

    private func hasActivity(on day: CalendarScrollDay) -> Bool {
        !entries(for: day).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .environment(\.colorScheme, .dark)

            GeometryReader { geo in
                let size = geo.size

                ScrollView(.vertical) {
                    LazyVStack(spacing: 15, pinnedViews: [.sectionHeaders]) {
                        ForEach(currentWeek) { day in
                            let date = day.date
                            let isLast = currentWeek.last?.id == day.id
                            let dayEntries = entries(for: day)

                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    if dayEntries.isEmpty {
                                        calendarEmptyDay
                                    } else {
                                        ForEach(dayEntries) { entry in
                                            row(for: entry)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.leading, 70)
                                .padding(.top, -70)
                                .padding(.bottom, 10)
                                .frame(minHeight: isLast ? size.height - 110 : nil, alignment: .top)
                            } header: {
                                VStack(spacing: 4) {
                                    Text(date.calendarScrollString("EEE"))

                                    Text(date.calendarScrollString("dd"))
                                        .font(.largeTitle.bold())
                                }
                                .frame(width: 55, height: 70)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.all, 20, for: .scrollContent)
                .contentMargins(.vertical, 20, for: .scrollIndicators)
                .scrollPosition(
                    id: .init(
                        get: {
                            currentWeek.first(where: { $0.date.calendarScrollIsSame(selectedDate) })?.id
                        },
                        set: { newValue in
                            selectedDate = currentWeek.first(where: { $0.id == newValue })?.date
                        }
                    ),
                    anchor: .top
                )
                .safeAreaPadding(.bottom, 70)
                .padding(.bottom, -70)
            }
            .background(.background)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 30,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 30,
                    style: .continuous
                )
            )
            .environment(\.colorScheme, .light)
            .ignoresSafeArea(.all, edges: .bottom)
        }
        .background(Color.calendarScrollMainBackground)
        .onAppear {
            if selectedDate == nil {
                selectedDate = currentWeek.first(where: { $0.date.calendarScrollIsSame(.now) })?.date
            }
            reloadActivity()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: viewContext)) { _ in
            reloadActivity()
        }
        .onChange(of: dataService.updateTrigger) { _, _ in
            reloadActivity()
        }
        .refreshable {
            await syncService.syncAfterServerMutation()
            reloadActivity()
        }
    }

    private var calendarEmptyDay: some View {
        VStack(spacing: 8) {
            Text("Aucune activité ce jour-là")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Les scans et nouvelles cartes apparaissent ici selon la même logique que l’accueil.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func row(for entry: DashboardActivityEntry) -> some View {
        if let card = viewContext.object(with: entry.cardObjectID) as? ClientCard {
            NavigationLink {
                MemberDetailView(card: card, context: viewContext)
                    .environmentObject(syncService)
                    .environmentObject(dataService)
            } label: {
                CalendarScrollActivityRow(entry: entry)
            }
            .buttonStyle(.plain)
        } else {
            CalendarScrollActivityRow(entry: entry)
        }
    }

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cette semaine")
                    .font(.title.bold())
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                ForEach(currentWeek) { day in
                    let date = day.date
                    let isSameDate = date.calendarScrollIsSame(selectedDate)
                    let hasDot = hasActivity(on: day)

                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text(date.calendarScrollString("EEE"))
                                .font(.caption)
                            if hasDot {
                                Circle()
                                    .fill(Color.cyan.opacity(0.95))
                                    .frame(width: 5, height: 5)
                                    .accessibilityLabel("Activité ce jour")
                            }
                        }

                        Text(date.calendarScrollString("dd"))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSameDate ? .black : .white)
                            .frame(width: 38, height: 38)
                            .background {
                                if isSameDate {
                                    Circle()
                                        .fill(.white)
                                        .matchedGeometryEffect(id: "ACTIVEDATE", in: namespace)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                            selectedDate = date
                        }
                    }
                }
            }
            .animation(.snappy(duration: 0.25, extraBounce: 0), value: selectedDate)
            .frame(height: 80)
            .padding(.vertical, 5)
            .offset(y: 5)

            HStack {
                Text(selectedDate?.calendarScrollString("MMM") ?? "")

                Spacer()

                Text(selectedDate?.calendarScrollString("YYYY") ?? "")
            }
            .font(.caption2)
        }
        .padding([.horizontal, .top], 15)
        .padding(.bottom, 10)
    }
}

// MARK: - Palette (calendrier)

extension Color {
    /// Même valeur sRGB que l’asset MainBackground du module CalendarScrollEffect (0.133³).
    static var calendarScrollMainBackground: Color {
        Color(red: 0.133, green: 0.133, blue: 0.133)
    }
}

#if DEBUG
#Preview {
    CalendarScrollEffectHomeView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
}
#endif
