import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: TimeStore
    @State private var newCity: String = ""
    @State private var newTZ: String = "Europe/Berlin"
    @State private var tzSearch: String = ""
    @State private var addError: String = ""
    @State private var partToAdd: CopyToken = .time24
    @State private var presetName: String = ""
    @State private var presetError: String = ""

    var filteredTZIDs: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        let q = tzSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var pickerVisibleIDs: [String] {
        Array(filteredTZIDs.prefix(50))
    }

    var availableTokensToAdd: [CopyToken] {
        CopyToken.allCases.filter { !store.isCopyTokenEnabled($0) }
    }

    var cityGuess: String? {
        TimeStore.suggestedTimeZoneID(forCity: newCity)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Time Zones")
                    .font(.system(size: 14, weight: .semibold))
                Text("Local (system time zone) is shown by default. Add up to \(TimeStore.maxExtras) more (\(store.extraIDs.count)/\(TimeStore.maxExtras)).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("City names are shown on the left and in copies. Edit to rename. Unchecked zones are hidden.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                    Text("Local")
                        .font(.system(size: 13))
                    TextField("City", text: cityBinding(id: "local", defaultCity: store.localDef.defaultCity))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .frame(width: 120)
                    Spacer()
                    Text("Selected by default")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                ForEach(store.allCatalog) { zone in
                    let selected = store.isSelected(id: zone.id)
                    let canSelect = selected || store.canAddMore()
                    HStack(spacing: 8) {
                        Button {
                            store.toggle(id: zone.id)
                        } label: {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSelect)
                        .help(selected ? "Hide this zone" : "Show this zone")
                        TextField(zone.defaultCity, text: cityBinding(id: zone.id, defaultCity: zone.defaultCity))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .frame(width: 120)
                        Spacer()
                        Text(zone.timeZone.identifier)
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if store.isCustomZone(id: zone.id) {
                            Button {
                                store.removeCustomZone(id: zone.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Delete \(store.cityName(for: zone))")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .opacity(canSelect ? 1.0 : 0.4)
                    .contextMenu {
                        if store.isCustomZone(id: zone.id) {
                            Button(role: .destructive) {
                                store.removeCustomZone(id: zone.id)
                            } label: {
                                Text("Delete \(store.cityName(for: zone))")
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add your own city and time zone")
                        .font(.system(size: 12, weight: .semibold))
                    TextField("City (e.g. Austin)", text: $newCity)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .help("Type a city name - we will guess its time zone")
                    if let guess = cityGuess, !newCity.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                            Text("\(newCity.trimmingCharacters(in: .whitespaces)) looks like \(guess)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Use") {
                                newTZ = guess
                                tzSearch = ""
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    TextField("Search time zones (e.g. Chicago, Berlin, Seoul)", text: $tzSearch)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .help("Type to filter the time zone list below")
                    if !filteredTZIDs.isEmpty {
                        Text("\(filteredTZIDs.count) matches\(filteredTZIDs.count > 50 ? " - showing first 50, refine search" : ""). Selected: \(newTZ)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(pickerVisibleIDs, id: \.self) { tz in
                                    Button {
                                        newTZ = tz
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: newTZ == tz ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(newTZ == tz ? Color.accentColor : Color.secondary)
                                                .font(.system(size: 11))
                                            Text(tz)
                                                .font(.system(size: 12).monospacedDigit())
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(newTZ == tz ? Color.accentColor.opacity(0.12) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                        }
                        .frame(height: 140)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        Text("No time zones match \"\(tzSearch)\".")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Button("Add") {
                            if store.addCustomZone(city: newCity, timeZoneID: newTZ) {
                                newCity = ""
                                tzSearch = ""
                                addError = ""
                            } else {
                                addError = "Check city, valid Zone ID, and room (max \(TimeStore.maxExtras))."
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!store.canAddMore() || newCity.trimmingCharacters(in: .whitespaces).isEmpty)
                        Spacer()
                        Text("Custom zones can be removed with the trash icon.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if !addError.isEmpty {
                        Text(addError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                Divider()
                Text("Copy Format")
                    .font(.system(size: 14, weight: .semibold))
                Text("Select parts to include. Use the arrows to change order.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                VStack(spacing: 2) {
                    ForEach(store.copyOrder) { token in
                        HStack(spacing: 8) {
                            Text("\(store.copyOrder.firstIndex(of: token)! + 1)")
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(token.title)
                                .font(.system(size: 12))
                            Spacer()
                            Text(token.example)
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button {
                                store.moveCopyToken(id: token, by: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(store.copyOrder.first == token)
                            .help("Move up")
                            Button {
                                store.moveCopyToken(id: token, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(store.copyOrder.last == token)
                            .help("Move down")
                            Button {
                                store.toggleCopyToken(token)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from copy")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if store.copyOrder.isEmpty {
                        Text("Nothing selected. Add a part below.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                HStack(spacing: 6) {
                    Picker("Add part", selection: $partToAdd) {
                        ForEach(availableTokensToAdd) { token in
                            Text(token.title).tag(token)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                    .disabled(availableTokensToAdd.isEmpty)
                    Button("Add") {
                        if !store.isCopyTokenEnabled(partToAdd) {
                            store.toggleCopyToken(partToAdd)
                        }
                        if let next = CopyToken.allCases.first(where: { !store.isCopyTokenEnabled($0) }) {
                            partToAdd = next
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(availableTokensToAdd.isEmpty)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                HStack(spacing: 8) {
                    Text("Preview:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let first = store.zones.first {
                        Text(store.copyLine(for: first))
                            .font(.system(size: 12).monospacedDigit())
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Reset") {
                        store.resetCopyFormat()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                }
                .padding(.top, 4)
                Divider()
                Text("Copy Presets")
                    .font(.system(size: 14, weight: .semibold))
                Text("Save the current format under a name like Customers or Work, then apply with one click.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("Preset name (e.g. Work)", text: $presetName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                    Button("Save") {
                        if store.saveCopyPreset(name: presetName) {
                            presetName = ""
                            presetError = ""
                        } else {
                            presetError = "Enter a name and include at least one part."
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                if !presetError.isEmpty {
                    Text(presetError)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                if store.copyPresets.isEmpty {
                    Text("No presets yet. Configure parts above and save.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 2) {
                        ForEach(store.copyPresets) { preset in
                            let isActive = store.copyOrder == preset.tokens
                            HStack(spacing: 8) {
                                Button("Apply") {
                                    store.applyCopyPreset(id: preset.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Apply preset \(preset.name)")
                                Button {
                                    store.applyCopyPreset(id: preset.id)
                                } label: {
                                    Text(preset.name)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .help("Apply preset \(preset.name)")
                                if isActive {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Text(preset.tokens.map { $0.example }.joined(separator: " "))
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Button {
                                    store.deleteCopyPreset(id: preset.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Delete preset")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isActive ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 360, height: 520)
        .onAppear {
            if !TimeZone.knownTimeZoneIdentifiers.contains(newTZ) {
                newTZ = TimeZone.knownTimeZoneIdentifiers.sorted().first ?? "UTC"
            }
            if let firstAvailable = availableTokensToAdd.first {
                partToAdd = firstAvailable
            }
        }
    }

    private func cityBinding(id: String, defaultCity: String) -> Binding<String> {
        Binding(
            get: {
                store.customCities[id] ?? defaultCity
            },
            set: { newValue in
                store.setCityName(id: id, name: newValue)
            }
        )
    }
}
