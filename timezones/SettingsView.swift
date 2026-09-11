import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: TimeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time Zones")
                .font(.system(size: 14, weight: .semibold))

            Text("Local (system time zone) is shown by default. Add up to \(TimeStore.maxExtras) more (\(store.extraIDs.count)/\(TimeStore.maxExtras)).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("City names are shown on the left and in copies. Edit to rename.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

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

            ForEach(TimeStore.catalog) { zone in
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
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .opacity(canSelect ? 1.0 : 0.4)
            }

            Spacer()
        }
        .padding(14)
        .frame(width: 340)
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
