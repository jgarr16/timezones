import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: TimeStore
    @State private var newCity: String = ""
    @State private var newTZ: String = ""
    @State private var addError: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Time Zones")
                    .font(.system(size: 14, weight: .semibold))

                Text("Local (system time zone) is shown by default. Add up to \(TimeStore.maxExtras) more (\(store.extraIDs.count)/\(TimeStore.maxExtras)).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text("City names are shown on the left and in copies. Edit to rename.")
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
                            .help("Remove custom zone")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .opacity(canSelect ? 1.0 : 0.4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Add your own city and time zone")
                        .font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 6) {
                        TextField("City (e.g. Berlin)", text: $newCity)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 130)
                        TextField("Zone ID (e.g. Europe/Berlin)", text: $newTZ)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 150)
                        Button("Add") {
                            if store.addCustomZone(city: newCity, timeZoneID: newTZ) {
                                newCity = ""
                                newTZ = ""
                                addError = ""
                            } else {
                                addError = "Check city, valid Zone ID, and room (max \(TimeStore.maxExtras))."
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!store.canAddMore())
                    }
                    if !addError.isEmpty {
                        Text(addError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    Text("Use an IANA name like America/Chicago or Asia/Seoul.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
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
                    ForEach(store.orderedTokensForDisplay()) { token in
                        let enabled = store.isCopyTokenEnabled(token)
                        let orderIndex = store.copyOrder.firstIndex(of: token)
                        HStack(spacing: 8) {
                            Button {
                                store.toggleCopyToken(token)
                            } label: {
                                Image(systemName: enabled ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            if let idx = orderIndex {
                                Text("\(idx + 1)")
                                    .font(.system(size: 11).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                            } else {
                                Color.clear.frame(width: 18)
                            }
                            Text(token.title)
                                .font(.system(size: 12))
                                .foregroundStyle(enabled ? .primary : .secondary)
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
                            .disabled(!enabled || store.copyOrder.first == token)
                            Button {
                                store.moveCopyToken(id: token, by: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(!enabled || store.copyOrder.last == token)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(enabled ? Color.accentColor.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

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
            }
            .padding(14)
        }
        .frame(width: 360, height: 520)
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
