//
//  GoogleBusinessInsightsView.swift
//  myfidpass
//
//  Statistiques de la fiche (API Business Profile Performance) : impressions Maps/Search,
//  appels, clics site, itinéraires, conversations, réservations.
//

import Charts
import SwiftUI
import Combine

@MainActor
final class GoogleBusinessInsightsVM: ObservableObject {
    @Published var response: GoogleBusinessInsightsResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var days: Int = 30

    private let slug: String
    init(slug: String) { self.slug = slug }

    func load(forceFresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.response = try await GoogleBusinessAPI.shared.insights(slug: slug, days: days, forceFresh: forceFresh)
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct GoogleBusinessInsightsView: View {
    let slug: String
    @StateObject private var vm: GoogleBusinessInsightsVM

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessInsightsVM(slug: slug))
    }

    private static let dfIn: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker
                if vm.isLoading && vm.response == nil {
                    ProgressView().padding(40)
                } else if let summary = vm.response?.summary {
                    kpiGrid(summary)
                    if let series = vm.response?.metrics {
                        impressionsChart(series: series)
                        actionsChart(series: series)
                    }
                } else if let err = vm.errorMessage {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding(16)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.load(forceFresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await vm.load() }
    }

    private var rangePicker: some View {
        Picker("Période", selection: $vm.days) {
            Text("7 j").tag(7)
            Text("30 j").tag(30)
            Text("90 j").tag(90)
        }
        .pickerStyle(.segmented)
        .onChange(of: vm.days) { _, _ in
            Task { await vm.load() }
        }
    }

    private func kpiGrid(_ s: GoogleBusinessInsightsSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            kpiCard(title: "Impressions totales", value: s.impressionsTotal, icon: "eye.fill", color: .blue)
            kpiCard(title: "Sur Maps", value: s.impressionsMaps, icon: "map.fill", color: .green)
            kpiCard(title: "Sur Search", value: s.impressionsSearch, icon: "magnifyingglass", color: .purple)
            kpiCard(title: "Appels 📞", value: s.calls, icon: "phone.fill", color: .orange)
            kpiCard(title: "Clics site web", value: s.websiteClicks, icon: "safari.fill", color: .teal)
            kpiCard(title: "Itinéraires", value: s.directions, icon: "location.fill", color: .indigo)
            if s.conversations > 0 {
                kpiCard(title: "Messages", value: s.conversations, icon: "bubble.left.and.bubble.right.fill", color: .pink)
            }
            if s.bookings > 0 {
                kpiCard(title: "Réservations", value: s.bookings, icon: "calendar.badge.clock", color: .mint)
            }
        }
    }

    private func kpiCard(title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Spacer()
            }
            Text(Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(value))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 3, x: 0, y: 1)
        )
    }

    private func impressionsChart(series: [String: GoogleBusinessMetricSeries]) -> some View {
        let mapsPoints = (series["BUSINESS_IMPRESSIONS_DESKTOP_MAPS"]?.series ?? []) +
                         (series["BUSINESS_IMPRESSIONS_MOBILE_MAPS"]?.series ?? [])
        let searchPoints = (series["BUSINESS_IMPRESSIONS_DESKTOP_SEARCH"]?.series ?? []) +
                           (series["BUSINESS_IMPRESSIONS_MOBILE_SEARCH"]?.series ?? [])
        let mapsByDate = groupByDate(mapsPoints)
        let searchByDate = groupByDate(searchPoints)
        let dates = Array(Set(mapsByDate.keys).union(searchByDate.keys)).sorted()

        return VStack(alignment: .leading, spacing: 8) {
            Text("Impressions (Maps vs Search)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Chart {
                ForEach(dates, id: \.self) { d in
                    LineMark(
                        x: .value("Date", toDate(d) ?? Date()),
                        y: .value("Maps", mapsByDate[d] ?? 0)
                    )
                    .foregroundStyle(by: .value("Source", "Maps"))
                    LineMark(
                        x: .value("Date", toDate(d) ?? Date()),
                        y: .value("Search", searchByDate[d] ?? 0)
                    )
                    .foregroundStyle(by: .value("Source", "Search"))
                }
            }
            .frame(height: 200)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 3, x: 0, y: 1)
        )
    }

    private func actionsChart(series: [String: GoogleBusinessMetricSeries]) -> some View {
        let callSeries = series["CALL_CLICKS"]?.series ?? []
        let websiteSeries = series["WEBSITE_CLICKS"]?.series ?? []
        let directionSeries = series["BUSINESS_DIRECTION_REQUESTS"]?.series ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text("Actions clients")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Chart {
                ForEach(callSeries) { p in
                    BarMark(
                        x: .value("Date", toDate(p.date) ?? Date()),
                        y: .value("Appels", p.value)
                    )
                    .foregroundStyle(by: .value("Action", "Appels"))
                }
                ForEach(websiteSeries) { p in
                    BarMark(
                        x: .value("Date", toDate(p.date) ?? Date()),
                        y: .value("Site web", p.value)
                    )
                    .foregroundStyle(by: .value("Action", "Site web"))
                }
                ForEach(directionSeries) { p in
                    BarMark(
                        x: .value("Date", toDate(p.date) ?? Date()),
                        y: .value("Itinéraire", p.value)
                    )
                    .foregroundStyle(by: .value("Action", "Itinéraire"))
                }
            }
            .frame(height: 200)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 3, x: 0, y: 1)
        )
    }

    private func groupByDate(_ pts: [GoogleBusinessMetricPoint]) -> [String: Double] {
        var m: [String: Double] = [:]
        for p in pts {
            m[p.date, default: 0] += p.value
        }
        return m
    }

    private func toDate(_ s: String) -> Date? { Self.dfIn.date(from: s) }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()
}
