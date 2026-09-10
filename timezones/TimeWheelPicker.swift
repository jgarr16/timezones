import SwiftUI

// Compact bare-bones HH:mm entry. Kept under the same name so all
// time inputs still go through one component.
struct TimeWheelPicker: View {
    let hour: Int
    let minute: Int
    let onHourChanged: (Int) -> Void
    let onMinuteChanged: (Int) -> Void

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
                .frame(width: 26)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .font(.system(size: 13).monospacedDigit())
                .onSubmit { commitHour() }
                .onChange(of: focusedField) { _, newValue in
                    if newValue == nil {
                        commitHour()
                        commitMinute()
                    }
                }

            Text(":")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)

            TextField("", text: $minuteText)
                .focused($focusedField, equals: .minute)
                .frame(width: 26)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.plain)
                .font(.system(size: 13).monospacedDigit())
                .onSubmit { commitMinute() }
        }
        .onAppear {
            syncFromProps()
        }
        .onChange(of: hour) { _, _ in
            if focusedField == nil { syncFromProps() }
        }
        .onChange(of: minute) { _, _ in
            if focusedField == nil { syncFromProps() }
        }
    }

    private func syncFromProps() {
        hourText = String(format: "%02d", hour)
        minuteText = String(format: "%02d", minute)
    }

    private func commitHour() {
        let trimmed = hourText.trimmingCharacters(in: .whitespaces)
        if let v = Int(trimmed), (0..<24).contains(v) {
            if v != hour { onHourChanged(v) }
            hourText = String(format: "%02d", v)
        } else {
            hourText = String(format: "%02d", hour)
        }
    }

    private func commitMinute() {
        let trimmed = minuteText.trimmingCharacters(in: .whitespaces)
        if let v = Int(trimmed), (0..<60).contains(v) {
            if v != minute { onMinuteChanged(v) }
            minuteText = String(format: "%02d", v)
        } else {
            minuteText = String(format: "%02d", minute)
        }
    }
}
