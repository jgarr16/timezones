import SwiftUI

struct TimeWheelPicker: View {
    let hour: Int
    let minute: Int
    let isEnabled: Bool
    let onHourChanged: (Int) -> Void
    let onMinuteChanged: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("HR")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Hour", selection: Binding(
                    get: { hour },
                    set: { newValue in
                        if newValue != hour {
                            onHourChanged(newValue)
                        }
                    }
                )) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .font(.system(size: 14).monospacedDigit())
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 90)
                .clipped()
                .disabled(!isEnabled)
            }

            Text(":")
                .font(.system(size: 20, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            VStack(spacing: 4) {
                Text("MIN")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Picker("Minute", selection: Binding(
                    get: { minute },
                    set: { newValue in
                        if newValue != minute {
                            onMinuteChanged(newValue)
                        }
                    }
                )) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .font(.system(size: 14).monospacedDigit())
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 90)
                .clipped()
                .disabled(!isEnabled)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
