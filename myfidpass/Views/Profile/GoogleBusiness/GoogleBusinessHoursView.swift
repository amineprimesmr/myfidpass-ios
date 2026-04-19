//
//  GoogleBusinessHoursView.swift
//  myfidpass
//
//  Édition des horaires réguliers, de la description et du site web de la fiche Google Business.
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessHoursVM: ObservableObject {
    @Published var location: GoogleBusinessLocationInfo?
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    @Published var websiteUri: String = ""
    @Published var description: String = ""

    /// Édition : jour → liste de plages (open/close).
    @Published var weeklyHours: [DayOfWeek: [HourRange]] = [:]

    enum DayOfWeek: String, CaseIterable, Identifiable {
        case monday = "MONDAY"
        case tuesday = "TUESDAY"
        case wednesday = "WEDNESDAY"
        case thursday = "THURSDAY"
        case friday = "FRIDAY"
        case saturday = "SATURDAY"
        case sunday = "SUNDAY"
        var id: String { rawValue }
        var frenchShort: String {
            switch self {
            case .monday: return "Lundi"
            case .tuesday: return "Mardi"
            case .wednesday: return "Mercredi"
            case .thursday: return "Jeudi"
            case .friday: return "Vendredi"
            case .saturday: return "Samedi"
            case .sunday: return "Dimanche"
            }
        }
    }

    struct HourRange: Identifiable, Equatable {
        let id: UUID = UUID()
        var open: (hours: Int, minutes: Int)
        var close: (hours: Int, minutes: Int)

        static func == (lhs: HourRange, rhs: HourRange) -> Bool {
            lhs.id == rhs.id &&
            lhs.open.hours == rhs.open.hours && lhs.open.minutes == rhs.open.minutes &&
            lhs.close.hours == rhs.close.hours && lhs.close.minutes == rhs.close.minutes
        }
    }

    private let slug: String
    init(slug: String) { self.slug = slug }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await GoogleBusinessAPI.shared.location(slug: slug)
            self.location = r.location
            self.websiteUri = r.location.websiteUri ?? ""
            self.description = r.location.profile?.description ?? ""
            self.weeklyHours = Self.parseHours(from: r.location.regularHours)
            self.errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func save() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        var patch = GoogleBusinessAPI.LocationPatchPayload()
        let originalSite = location?.websiteUri ?? ""
        let originalDesc = location?.profile?.description ?? ""
        if websiteUri != originalSite {
            patch.websiteUri = websiteUri
        }
        if description != originalDesc {
            patch.profile = .init(description: description)
        }
        // Always send hours (it's simpler and avoids diff complexity).
        patch.regularHours = GoogleBusinessRegularHours(periods: Self.serializeHours(weeklyHours))
        do {
            let newLoc = try await GoogleBusinessAPI.shared.patchLocation(slug: slug, patch: patch)
            self.location = newLoc
            self.errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func addRange(for day: DayOfWeek) {
        weeklyHours[day, default: []].append(HourRange(open: (9, 0), close: (18, 0)))
    }

    func removeRange(for day: DayOfWeek, at index: Int) {
        guard let _ = weeklyHours[day]?.indices.contains(index) else { return }
        weeklyHours[day]?.remove(at: index)
    }

    static func parseHours(from hours: GoogleBusinessRegularHours?) -> [DayOfWeek: [HourRange]] {
        guard let periods = hours?.periods else { return [:] }
        var out: [DayOfWeek: [HourRange]] = [:]
        for p in periods {
            guard let day = DayOfWeek(rawValue: p.openDay),
                  let openH = p.openTime?.hours,
                  let closeH = p.closeTime?.hours else { continue }
            let openM = p.openTime?.minutes ?? 0
            let closeM = p.closeTime?.minutes ?? 0
            out[day, default: []].append(HourRange(open: (openH, openM), close: (closeH, closeM)))
        }
        return out
    }

    static func serializeHours(_ hours: [DayOfWeek: [HourRange]]) -> [GoogleBusinessHourPeriod] {
        var res: [GoogleBusinessHourPeriod] = []
        for day in DayOfWeek.allCases {
            for r in (hours[day] ?? []) {
                res.append(GoogleBusinessHourPeriod(
                    openDay: day.rawValue,
                    openTime: GoogleBusinessHourTime(hours: r.open.hours, minutes: r.open.minutes),
                    closeDay: day.rawValue,
                    closeTime: GoogleBusinessHourTime(hours: r.close.hours, minutes: r.close.minutes)
                ))
            }
        }
        return res
    }
}

struct GoogleBusinessHoursView: View {
    let slug: String
    @StateObject private var vm: GoogleBusinessHoursVM
    @State private var savedOnce = false

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessHoursVM(slug: slug))
    }

    var body: some View {
        Form {
            if vm.isLoading && vm.location == nil {
                Section { ProgressView() }
            } else {
                Section("Informations de base") {
                    if let title = vm.location?.title {
                        LabeledContent("Nom", value: title)
                    }
                    TextField("Site web", text: $vm.websiteUri)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $vm.description)
                            .frame(minHeight: 90)
                    }
                }
                Section {
                    ForEach(GoogleBusinessHoursVM.DayOfWeek.allCases) { day in
                        daySection(day)
                    }
                } header: {
                    Text("Horaires d'ouverture")
                } footer: {
                    Text("Les modifications sont publiées immédiatement sur Google Maps.")
                        .font(.caption)
                }
                if savedOnce {
                    Section {
                        Label("Mise à jour enregistrée — peut prendre 1 à 2 minutes pour apparaître sur Google.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.footnote)
                    }
                }
                if let err = vm.errorMessage {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
        }
        .navigationTitle("Horaires & infos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        let ok = await vm.save()
                        if ok { savedOnce = true }
                    }
                } label: {
                    if vm.isSaving { ProgressView().controlSize(.small) }
                    else { Text("Enregistrer").font(.body.weight(.semibold)) }
                }
                .disabled(vm.isSaving || vm.isLoading)
            }
        }
        .task { await vm.load() }
    }

    @ViewBuilder
    private func daySection(_ day: GoogleBusinessHoursVM.DayOfWeek) -> some View {
        let ranges = vm.weeklyHours[day] ?? []
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.frenchShort)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    vm.addRange(for: day)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            if ranges.isEmpty {
                Text("Fermé")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(Array(ranges.enumerated()), id: \.element.id) { (idx, r) in
                    HStack(spacing: 6) {
                        timeField(hours: Binding(
                            get: { vm.weeklyHours[day]?[idx].open.hours ?? 9 },
                            set: { vm.weeklyHours[day]?[idx].open.hours = $0 }
                        ), minutes: Binding(
                            get: { vm.weeklyHours[day]?[idx].open.minutes ?? 0 },
                            set: { vm.weeklyHours[day]?[idx].open.minutes = $0 }
                        ))
                        Text("→")
                        timeField(hours: Binding(
                            get: { vm.weeklyHours[day]?[idx].close.hours ?? 18 },
                            set: { vm.weeklyHours[day]?[idx].close.hours = $0 }
                        ), minutes: Binding(
                            get: { vm.weeklyHours[day]?[idx].close.minutes ?? 0 },
                            set: { vm.weeklyHours[day]?[idx].close.minutes = $0 }
                        ))
                        Spacer()
                        Button(role: .destructive) {
                            vm.removeRange(for: day, at: idx)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    private func timeField(hours: Binding<Int>, minutes: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            Picker("h", selection: hours) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 55, height: 90)
            .clipped()
            Text(":")
            Picker("m", selection: minutes) {
                ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 55, height: 90)
            .clipped()
        }
    }
}
