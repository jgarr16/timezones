import SwiftUI

// Compact bare-bones HH:mm entry. Kept under the same name so all
// time inputs still go through one component.
// Live-commit version: valid typing immediately syncs bidirectional state.
// Up/Down arrows: hour steps 1h, minute snaps to 0/30 in direction then 30min steps.
struct TimeWheelPicker: View {
    let hour: Int
    let minute: Int
    let onHourChanged: (Int) -> Void
    let onMinuteChanged: (Int) -> Void
    var onHourStep: (Int) -> Void = { _ in }
    var onMinuteStep: (Int) -> Void = { _ in }

    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case hour, minute
    }

    var body: some View {
        HStack(spacing: 2) {
            TextField("", text: $hourText)
                .focused($focusedField, equals: .hour)
                .frame(width: 32)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .font(.system(size: 13).monospacedDigit())
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(focusedField == .hour ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.25), lineWidth: 1)
                        )
                )
                .help("Hour 0-23 (Up/Down to step 1h)")
                .onSubmit { normalizeHour() }
                .onKeyPress(.upArrow) {
                    DispatchQueue.main.async { onHourStep(1) }
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    DispatchQueue.main.async { onHourStep(-1) }
                    return .handled
                }
                .onChange(of: hourText) { _, newValue in
                    // Allow empty while typing, otherwise live-commit valid 0-23.
                    // Deferred to avoid publishing TimeStore during view update.
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return }
                    if let v = Int(trimmed), (0..<24).contains(v) {
                        if v != hour {
                            DispatchQueue.main.async { onHourChanged(v) }
                        }
                    }
                }

            Text(":")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)

            TextField("", text: $minuteText)
                .focused($focusedField, equals: .minute)
                .frame(width: 32)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .font(.system(size: 13).monospacedDigit())
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(focusedField == .minute ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.25), lineWidth: 1)
                        )
                )
                .help("Minute (Up/Down snaps to 0/30 then 30min steps)")
                .onSubmit { normalizeMinute() }
                .onKeyPress(.upArrow) {
                    DispatchQueue.main.async { onMinuteStep(1) }
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    DispatchQueue.main.async { onMinuteStep(-1) }
                    return .handled
                }
                .onChange(of: minuteText) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { return }
                    if let v = Int(trimmed), (0..<60).contains(v) {
                        if v != minute {
                            DispatchQueue.main.async { onMinuteChanged(v) }
                        }
                    }
                }
        }
        .onAppear {
            syncFromProps()
        }
        .onChange(of: hour) { _, newHour in
            if focusedField != .hour {
                hourText = String(format: "%02d", newHour)
            } else {
                // Focused: only refresh if stale valid entry (arrow step).
                // Leave empty/invalid alone for typing.
                let trimmed = hourText.trimmingCharacters(in: .whitespaces)
                if let v = Int(trimmed), (0..<24).contains(v), v != newHour {
                    hourText = String(format: "%02d", newHour)
                }
            }
        }
        .onChange(of: minute) { _, newMinute in
            if focusedField != .minute {
                minuteText = String(format: "%02d", newMinute)
            } else {
                let trimmed = minuteText.trimmingCharacters(in: .whitespaces)
                if let v = Int(trimmed), (0..<60).contains(v), v != newMinute {
                    minuteText = String(format: "%02d", newMinute)
                }
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            // Normalize the field we just left. When focus leaves
            // entirely (Now pressed + resign), normalize both.
            if oldValue == .hour && newValue != .hour {
                normalizeHour()
            }
            if oldValue == .minute && newValue != .minute {
                normalizeMinute()
            }
            if newValue == nil {
                syncFromProps()
            }
        }
    }

    private func syncFromProps() {
        // Don't clobber field currently being edited.
        if focusedField != .hour {
            hourText = String(format: "%02d", hour)
        }
        if focusedField != .minute {
            minuteText = String(format: "%02d", minute)
        }
        if focusedField == nil {
            hourText = String(format: "%02d", hour)
            minuteText = String(format: "%02d", minute)
        }
    }

    private func normalizeHour() {
        let trimmed = hourText.trimmingCharacters(in: .whitespaces)
        if let v = Int(trimmed), (0..<24).contains(v) {
            hourText = String(format: "%02d", v)
        } else {
            hourText = String(format: "%02d", hour)
        }
    }

    private func normalizeMinute() {
        let trimmed = minuteText.trimmingCharacters(in: .whitespaces)
        if let v = Int(trimmed), (0..<60).contains(v) {
            minuteText = String(format: "%02d", v)
        } else {
            minuteText = String(format: "%02d", minute)
        }
    }
}
