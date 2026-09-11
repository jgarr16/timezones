import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: TimeStore
    @State private var didCopy: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 6) {
                ForEach(store.zones) { zone in
                    let hm = store.hourMinute(for: store.baseDate, in: zone.timeZone)
                    HStack(spacing: 6) {
                        Button {
                            store.toggleCopy(id: zone.id)
                        } label: {
                            Image(systemName: store.isCopySelected(id: zone.id) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(store.isCopySelected(id: zone.id) ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Include in Copy Selected")
                        .frame(width: 18)
                        Text(store.cityName(for: zone))
                            .font(.system(size: 13))
                            .frame(width: 110, alignment: .leading)
                            .lineLimit(1)
                            .truncationMode(.tail)
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
                        Text(zone.abbreviation(for: store.baseDate))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                            .lineLimit(1)
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
                    Button(didCopy ? "Copied!" : "Copy Selected") {
                        copyAll()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                    .frame(width: 90)
                    .keyboardShortcut("m", modifiers: .command)
                    .help("Copy selected rows, one per line (Cmd+M)")
                    Spacer()
                    Color.clear
                        .frame(width: 60, height: 1)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
            TimeScrubberView(store: store)
        }
        .padding(10)
        .frame(width: 470)
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
        // Popover window keeps TextField focus otherwise,
        // which blocks sync and leaves stale minutes visible.
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
    }
}

struct TimeScrubberView: View {
    @ObservedObject var store: TimeStore
    @State private var translation: CGFloat = 0
    @State private var lastStepCount: Int = 0
    @State private var isDragging: Bool = false
    @State private var repeatTimer: Timer?

    private let trackHeight: CGFloat = 180
    private let maxDrag: CGFloat = 85

    var body: some View {
        VStack(spacing: 4) {
            Button {
                DispatchQueue.main.async {
                    store.stepMinute30(for: store.localDef, by: 1)
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 16)
            }
            .buttonStyle(.plain)
            .help("Step +30 min (snaps to :00 / :30 first)")

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 28, height: trackHeight)

                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 28, height: 1)
                    .offset(y: 0)

                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.accentColor.opacity(isDragging ? 0.9 : 0.6))
                    .frame(width: 22, height: 14)
                    .offset(y: translation)
                    .animation(isDragging ? nil : .easeOut(duration: 0.15), value: translation)

                if !isDragging {
                    Image(systemName: "chevrons.up.chevrons.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        let t = max(-maxDrag, min(maxDrag, value.translation.height))
                        translation = t
                        let steps = stepsForTranslation(t)
                        if steps != lastStepCount {
                            let diff = steps - lastStepCount
                            let dir = diff > 0 ? -1 : 1
                            for _ in 0..<abs(diff) {
                                DispatchQueue.main.async {
                                    store.stepMinute30(for: store.localDef, by: dir)
                                }
                            }
                            lastStepCount = steps
                        }
                        restartTimerIfNeeded()
                    }
                    .onEnded { _ in
                        stopTimer()
                        isDragging = false
                        lastStepCount = 0
                        withAnimation(.easeOut(duration: 0.15)) {
                            translation = 0
                        }
                    }
            )
            .help("Drag up / down to scrub time. First snaps to nearest :00 / :30 in that direction, then 30-min steps. Farther from center = faster.")

            Button {
                DispatchQueue.main.async {
                    store.stepMinute30(for: store.localDef, by: -1)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 16)
            }
            .buttonStyle(.plain)
            .help("Step -30 min (snaps to :00 / :30 first)")

            Text("30m")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 32)
        .onDisappear {
            stopTimer()
        }
    }

    private func stepsForTranslation(_ t: CGFloat) -> Int {
        if abs(t) < 8 { return 0 }
        if t < 0 {
            return Int((-t + 6) / 12)
        } else {
            return -Int((t + 6) / 12)
        }
    }

    private func restartTimerIfNeeded() {
        let absT = abs(translation)
        if absT < 18 || !isDragging {
            stopTimer()
            return
        }
        let interval: TimeInterval
        if absT < 35 {
            interval = 0.35
        } else if absT < 60 {
            interval = 0.12
        } else {
            interval = 0.05
        }
        if let t = repeatTimer, t.isValid, t.timeInterval == interval {
            return
        }
        stopTimer()
        let dir = translation < 0 ? 1 : -1
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                store.stepMinute30(for: store.localDef, by: dir)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    private func stopTimer() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
