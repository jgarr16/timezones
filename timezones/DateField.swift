import SwiftUI

// Two separate blocks: M and D, no leading zeros, no year display.
// Year is preserved from the current date in this zone.
// Single component for all date inputs, mirrors TimeWheelPicker.
// Up/Down arrows step month/day.
struct DateField: View {
    let date: Date
    let timeZone: TimeZone
    let onDateChanged: (Int, Int, Int) -> Void

    @State private var monthText: String = ""
    @State private var dayText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case month, day
    }

    var body: some View {
        HStack(spacing: 2) {
            TextField("", text: $monthText)
                .focused($focusedField, equals: .month)
                .frame(width: 28)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .font(.system(size: 12).monospacedDigit())
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(focusedField == .month ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
                        )
                )
                .help("Month in this zone (Up/Down to step)")
                .onSubmit { normalizeMonth() }
                .onKeyPress(.upArrow) {
                    stepMonth(by: 1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    stepMonth(by: -1)
                    return .handled
                }
                .onChange(of: monthText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return }
                    if let v = Int(trimmed), (1...12).contains(v) {
                        let cur = currentYMD()
                        if v != cur.m {
                            // Only commit if current day exists in new month.
                            // Deferred to avoid publishing TimeStore during view update.
                            if cur.d <= monthLength(year: cur.y, month: v) {
                                DispatchQueue.main.async {
                                    onDateChanged(cur.y, v, cur.d)
                                }
                            }
                        }
                    }
                }

            Text("/")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)

            TextField("", text: $dayText)
                .focused($focusedField, equals: .day)
                .frame(width: 28)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .font(.system(size: 12).monospacedDigit())
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(focusedField == .day ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
                        )
                )
                .help("Day in this zone (Up/Down to step)")
                .onSubmit { normalizeDay() }
                .onKeyPress(.upArrow) {
                    stepDay(by: 1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    stepDay(by: -1)
                    return .handled
                }
                .onChange(of: dayText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return }
                    if let v = Int(trimmed), (1...31).contains(v) {
                        let cur = currentYMD()
                        if v != cur.d {
                            if v <= monthLength(year: cur.y, month: cur.m) {
                                DispatchQueue.main.async {
                                    onDateChanged(cur.y, cur.m, v)
                                }
                            }
                        }
                    }
                }
        }
        .onAppear {
            syncFromProps()
        }
        .onChange(of: date) { _, _ in
            let cur = currentYMD()
            if focusedField == nil {
                syncFromProps()
            } else if focusedField == .month {
                // Other block always refreshes.
                dayText = "\(cur.d)"
                // Focused block only refreshes if stale valid entry (arrow step from another zone).
                // Leave invalid/empty alone so typing 0 -> 09 is not clobbered.
                let trimmed = monthText.trimmingCharacters(in: .whitespaces)
                if let v = Int(trimmed), (1...12).contains(v), v != cur.m {
                    monthText = "\(cur.m)"
                }
            } else if focusedField == .day {
                monthText = "\(cur.m)"
                let trimmed = dayText.trimmingCharacters(in: .whitespaces)
                if let v = Int(trimmed), (1...31).contains(v), v != cur.d {
                    dayText = "\(cur.d)"
                }
            }
        }
        .onChange(of: timeZone.identifier) { _, _ in
            syncFromProps()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .month && newValue != .month {
                normalizeMonth()
            }
            if oldValue == .day && newValue != .day {
                normalizeDay()
            }
            if newValue == nil {
                syncFromProps()
            }
        }
    }

    private func calendar() -> Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }

    private func currentYMD() -> (y: Int, m: Int, d: Int) {
        let cal = calendar()
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    private func monthLength(year: Int, month: Int) -> Int {
        TimeStore.monthLength(year: year, month: month, timeZone: timeZone)
    }

    private func notifyDateChanged(y: Int, m: Int, d: Int) {
        // Arrow steps originate from key press, but still defer to keep
        // TimeStore publishing outside the current view update.
        DispatchQueue.main.async {
            onDateChanged(y, m, d)
        }
    }

    private func stepMonth(by delta: Int) {
        let cur = currentYMD()
        var newM = cur.m + delta
        var newY = cur.y
        while newM < 1 {
            newM += 12
            newY -= 1
        }
        while newM > 12 {
            newM -= 12
            newY += 1
        }
        let newD = min(cur.d, monthLength(year: newY, month: newM))
        monthText = "\(newM)"
        if newD != cur.d {
            dayText = "\(newD)"
        }
        notifyDateChanged(y: newY, m: newM, d: newD)
    }

    private func stepDay(by delta: Int) {
        let cal = calendar()
        let cur = currentYMD()
        if let shifted = cal.date(byAdding: .day, value: delta, to: date) {
            let c = cal.dateComponents([.year, .month, .day], from: shifted)
            let newY = c.year ?? cur.y
            let newM = c.month ?? cur.m
            let newD = c.day ?? cur.d
            monthText = "\(newM)"
            dayText = "\(newD)"
            notifyDateChanged(y: newY, m: newM, d: newD)
        }
    }

    private func syncFromProps() {
        let cur = currentYMD()
        if focusedField != .month {
            monthText = "\(cur.m)"
        }
        if focusedField != .day {
            dayText = "\(cur.d)"
        }
        if focusedField == nil {
            monthText = "\(cur.m)"
            dayText = "\(cur.d)"
        }
    }

    private func normalizeMonth() {
        let cur = currentYMD()
        let trimmed = monthText.trimmingCharacters(in: .whitespaces)
        if let v = Int(trimmed), (1...12).contains(v),
           cur.d <= monthLength(year: cur.y, month: v) {
            monthText = "\(v)"
        } else {
            monthText = "\(cur.m)"
        }
    }

    private func normalizeDay() {
        let cur = currentYMD()
        let trimmed = dayText.trimmingCharacters(in: .whitespaces)
        if let v = Int(trimmed), (1...31).contains(v),
           v <= monthLength(year: cur.y, month: cur.m) {
            dayText = "\(v)"
        } else {
            dayText = "\(cur.d)"
        }
    }
}
