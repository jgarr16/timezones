import SwiftUI

// Two separate blocks: M and D, no leading zeros, no year display.
// Year is preserved from the current date in this zone.
// Single component for all date inputs, mirrors TimeWheelPicker.
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
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(focusedField == .month ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.25), lineWidth: 1)
                        )
                )
                .help("Month in this zone")
                .onSubmit { normalizeMonth() }
                .onChange(of: monthText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return }
                    if let v = Int(trimmed), (1...12).contains(v) {
                        let cur = currentYMD()
                        if v != cur.m {
                            // Only commit if current day exists in new month.
                            if cur.d <= monthLength(year: cur.y, month: v) {
                                onDateChanged(cur.y, v, cur.d)
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
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(focusedField == .day ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.25), lineWidth: 1)
                        )
                )
                .help("Day in this zone")
                .onSubmit { normalizeDay() }
                .onChange(of: dayText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return }
                    if let v = Int(trimmed), (1...31).contains(v) {
                        let cur = currentYMD()
                        if v != cur.d {
                            if v <= monthLength(year: cur.y, month: cur.m) {
                                onDateChanged(cur.y, cur.m, v)
                            }
                        }
                    }
                }
        }
        .onAppear {
            syncFromProps()
        }
        .onChange(of: date) { _, _ in
            if focusedField == nil {
                syncFromProps()
            } else if focusedField == .month {
                // Keep editing month, but refresh day block live.
                let cur = currentYMD()
                dayText = "\(cur.d)"
            } else if focusedField == .day {
                let cur = currentYMD()
                monthText = "\(cur.m)"
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
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let d = cal.date(from: comps),
              let r = cal.range(of: .day, in: .month, for: d) else {
            return 31
        }
        return r.count
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
