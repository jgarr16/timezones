import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: TimeStore
    @Environment(\.openWindow) private var openWindow
    @State private var didCopy: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ForEach(store.zones) { zone in
                let hm = store.hourMinute(for: store.baseDate, in: zone.timeZone)
                HStack(spacing: 6) {
                    Text(zone.title)
                        .font(.system(size: 13))
                        .frame(width: 58, alignment: .leading)
                        .lineLimit(1)
                    DateField(
                        date: store.baseDate,
                        timeZone: zone.timeZone,
                        onDateChanged: { y, m, d in
                            DispatchQueue.main.async {
                                store.setDate(for: zone, year: y, month: m, day: d)
                            }
                        }
                    )
                    TimeWheelPicker(
                        hour: hm.h,
                        minute: hm.m,
                        onHourChanged: { newHour in
                            DispatchQueue.main.async {
                                // Re-read current minute at call time to avoid
                                // stale capture overwriting a minute edit.
                                let cur = store.hourMinute(for: store.baseDate, in: zone.timeZone)
                                store.setTime(for: zone, newHour: newHour, newMinute: cur.m)
                            }
                        },
                        onMinuteChanged: { newMinute in
                            DispatchQueue.main.async {
                                let cur = store.hourMinute(for: store.baseDate, in: zone.timeZone)
                                store.setTime(for: zone, newHour: cur.h, newMinute: newMinute)
                            }
                        },
                        onHourStep: { delta in
                            DispatchQueue.main.async {
                                store.stepHour(for: zone, by: delta)
                            }
                        },
                        onMinuteStep: { delta in
                            DispatchQueue.main.async {
                                store.stepMinute30(for: zone, by: delta)
                            }
                        }
                    )
                    .layoutPriority(1)
                    Text(zone.gmtOffsetString(for: store.baseDate))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                        .lineLimit(1)
                    Button {
                        store.copySingleToClipboard(zone: zone)
                        didCopy = true
                        scheduleCopiedReset()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy this row as friendly text")
                    .frame(width: 18)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack(spacing: 8) {
                Button("Reset") {
                    clearFocus()
                    store.goLive()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .frame(width: 36, alignment: .leading)
                .opacity(store.isLive ? 0 : 1)
                .disabled(store.isLive)
                .frame(width: 60, alignment: .leading)
                Spacer()
                Button(didCopy ? "Copied!" : "Copy All") {
                    copyAll()
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .frame(width: 70)
                .keyboardShortcut("m", modifiers: .command)
                .help("Copy all rows as friendly text, one per line (Cmd+M)")
                Spacer()
                Button("Settings") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .frame(width: 50, alignment: .trailing)
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 360)
    }

    private func copyAll() {
        store.copyAllToClipboard()
        didCopy = true
        scheduleCopiedReset()
    }

    private func scheduleCopiedReset() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            didCopy = false
        }
    }

    private func clearFocus() {
        // MenuBarExtra window keeps TextField focus otherwise,
        // which blocks sync and leaves stale minutes visible.
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
    }
}
