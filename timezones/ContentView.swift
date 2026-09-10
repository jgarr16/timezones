import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: TimeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 6) {
            ForEach(store.zones) { zone in
                let hm = store.hourMinute(for: store.baseDate, in: zone.timeZone)
                HStack(spacing: 8) {
                    Text(zone.title)
                        .font(.system(size: 13))
                        .frame(width: 64, alignment: .leading)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    TimeWheelPicker(
                        hour: hm.h,
                        minute: hm.m,
                        onHourChanged: { newHour in
                            store.setTime(for: zone, newHour: newHour, newMinute: hm.m)
                        },
                        onMinuteChanged: { newMinute in
                            store.setTime(for: zone, newHour: hm.h, newMinute: newMinute)
                        }
                    )
                    .layoutPriority(1)
                    Text(zone.abbreviation(for: store.baseDate))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(store.isLive ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Button(store.isLive ? "Pause" : "Now") {
                    if store.isLive {
                        store.pause()
                    } else {
                        store.goLive()
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                Spacer()
                Button("Settings") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 280)
    }
}
