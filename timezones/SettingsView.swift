import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: TimeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time Zones")
                .font(.system(size: 14, weight: .semibold))

            Text("Local is always shown. Add up to \(TimeStore.maxExtras) more (\(store.extraIDs.count)/\(TimeStore.maxExtras)).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Local")
                    .font(.system(size: 13))
                Spacer()
                Text("Always on")
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

                    Text(zone.title)
                        .font(.system(size: 13))
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
        .frame(width: 300)
    }
}
