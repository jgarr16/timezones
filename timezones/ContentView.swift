import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: TimeStore
    @State private var didCopy: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ScrollView {
                LazyVStack(spacing: 6) {
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
                                .frame(width: 90, alignment: .leading)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            HStack(spacing: 2) {
                                DateField(
                                    date: store.baseDate,
                                    timeZone: zone.timeZone,
                                    onDateChanged: { y, m, d in
                                        DispatchQueue.main.async {
                                            store.setDate(for: zone, year: y, month: m, day: d)
                                        }
                                    }
                                )
                                ZoneCalendarButton(store: store, zone: zone)
                            }
                            HStack(spacing: 2) {
                                HoldStepButton(systemName: "minus", helpText: "Back 30 minutes (snaps to :00 / :30 first)") {
                                    store.stepMinute30(for: zone, by: -1)
                                }
                                TimeWheelPicker(
                                    hour: hm.h,
                                    minute: hm.m,
                                    onHourChanged: { newHour in
                                        DispatchQueue.main.async {
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
                                HoldStepButton(systemName: "plus", helpText: "Forward 30 minutes (snaps to :00 / :30 first)") {
                                    store.stepMinute30(for: zone, by: 1)
                                }
                            }
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
                }
            }
            .scrollIndicators(.never)
            .frame(maxHeight: 360)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Copy preview")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(previewLineCountText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .top, spacing: 8) {
                    ScrollView {
                        Text(previewText)
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(store.clipboardText.isEmpty ? .tertiary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 64)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                    Button(didCopy ? "Copied!" : "Copy") {
                        copyAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(width: 64)
                    .keyboardShortcut("m", modifiers: .command)
                    .help("Copy previewed rows, one per line (Cmd+M)")
                    .disabled(store.clipboardText.isEmpty)
                }
            }
            .padding(.horizontal, 4)

            Divider()

            HStack(spacing: 8) {
                Button("Now") {
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
                Text(store.isLive ? "Live" : "Paused - editing")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear
                    .frame(width: 60, height: 1)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(minWidth: 340, idealWidth: 380, maxWidth: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var previewText: String {
        if store.clipboardText.isEmpty {
            return "Check zones to include in copy."
        } else {
            return store.clipboardText
        }
    }

    private var previewLineCountText: String {
        if store.clipboardText.isEmpty {
            return "0 lines"
        } else {
            let n = store.clipboardText.components(separatedBy: "\n").count
            return n == 1 ? "1 line" : "\(n) lines"
        }
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
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
    }
}

struct ZoneCalendarButton: View {
    @ObservedObject var store: TimeStore
    let zone: ZoneDef
    @State private var showCalendar: Bool = false

    var body: some View {
        Button {
            showCalendar.toggle()
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Pick date in \(store.cityName(for: zone))")
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { store.baseDate },
                    set: { newValue in
                        let ymd = store.yearMonthDay(for: newValue, in: zone.timeZone)
                        DispatchQueue.main.async {
                            store.setDate(for: zone, year: ymd.y, month: ymd.m, day: ymd.d)
                        }
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .environment(\.timeZone, zone.timeZone)
            .padding(10)
            .frame(width: 280)
        }
    }
}

struct HoldStepButton: View {
    let systemName: String
    let helpText: String
    let action: () -> Void

    @State private var timer: Timer?
    @State private var startDate: Date?
    @State private var lastFire: Date?
    @State private var isPressing: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 20)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isPressing ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            isPressing = true
                            startDate = Date()
                            lastFire = Date()
                            action()
                            startTimer()
                        }
                    }
                    .onEnded { _ in
                        stopTimer()
                    }
            )
            .help(helpText)
            .onDisappear {
                stopTimer()
            }
    }

    private func startTimer() {
        stopTimerOnly()
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let start = startDate, let last = lastFire else { return }
            let now = Date()
            let elapsed = now.timeIntervalSince(start)
            let interval: TimeInterval
            if elapsed < 1.0 {
                interval = 0.30
            } else if elapsed < 2.5 {
                interval = 0.12
            } else {
                interval = 0.05
            }
            if now.timeIntervalSince(last) >= interval {
                lastFire = now
                action()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimerOnly() {
        timer?.invalidate()
        timer = nil
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        lastFire = nil
        isPressing = false
    }
}
