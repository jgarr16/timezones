import SwiftUI

// Compact editable date M/d/yy shown in a specific time zone.
// Single component for all date inputs, mirrors TimeWheelPicker.
struct DateField: View {
    let date: Date
    let timeZone: TimeZone
    let onDateChanged: (Int, Int, Int) -> Void

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .focused($isFocused)
            .frame(width: 64)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .font(.system(size: 12).monospacedDigit())
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isFocused ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.25), lineWidth: 1)
                    )
            )
            .help("Date M/d/yy in this zone")
            .onAppear {
                syncFromProps()
            }
            .onChange(of: date) { _, _ in
                if !isFocused {
                    syncFromProps()
                }
            }
            .onChange(of: timeZone.identifier) { _, _ in
                syncFromProps()
            }
            .onSubmit {
                commit()
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commit()
                }
            }
    }

    private func formatter() -> DateFormatter {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M/d/yy"
        return f
    }

    private func syncFromProps() {
        text = formatter().string(from: date)
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let (y, m, d) = parse(trimmed) {
            onDateChanged(y, m, d)
            // Re-format to normalized form after store updates.
            // Fall back to immediate format in case store rejects.
            let cal = Calendar.current
            var c = cal.dateComponents([.year, .month, .day], from: date)
            _ = c
            text = "\(m)/\(d)/\(String(format: "%02d", y % 100))"
        } else {
            syncFromProps()
        }
    }

    private func parse(_ s: String) -> (Int, Int, Int)? {
        // Accept M/d/yy, M/d/yyyy, M-d-yy, M.d.yy, or M/d (year = current year in zone).
        let separators = CharacterSet(charactersIn: "/-. ")
        let parts = s.components(separatedBy: separators).filter { !$0.isEmpty }
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard let m = Int(parts[0]), let d = Int(parts[1]) else { return nil }
        guard (1...12).contains(m), (1...31).contains(d) else { return nil }

        let y: Int
        if parts.count == 3 {
            guard let rawY = Int(parts[2]) else { return nil }
            if rawY < 100 {
                y = 2000 + rawY
            } else {
                y = rawY
            }
        } else {
            var cal = Calendar.current
            cal.timeZone = timeZone
            y = cal.component(.year, from: date)
        }
        return (y, m, d)
    }
}
