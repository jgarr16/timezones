import SwiftUI

struct TimeWheelPicker: View {
    let hour: Int
    let minute: Int
    let isEnabled: Bool
    let onHourChanged: (Int) -> Void
    let onMinuteChanged: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            WheelColumn(
                title: "HR",
                range: 0..<24,
                selection: hour,
                isEnabled: isEnabled,
                onSelect: { newValue in
                    if newValue != hour {
                        onHourChanged(newValue)
                    }
                }
            )

            Text(":")
                .font(.system(size: 20, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 36)

            WheelColumn(
                title: "MIN",
                range: 0..<60,
                selection: minute,
                isEnabled: isEnabled,
                onSelect: { newValue in
                    if newValue != minute {
                        onMinuteChanged(newValue)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WheelColumn: View {
    let title: String
    let range: Range<Int>
    let selection: Int
    let isEnabled: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                step(by: -1)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .help("Decrement")

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(range, id: \.self) { value in
                            let isSelected = (value == selection)
                            Button {
                                if value != selection {
                                    onSelect(value)
                                }
                            } label: {
                                Text(String(format: "%02d", value))
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular).monospacedDigit())
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                    .frame(width: 70, height: 22)
                                    .background(
                                        isSelected
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .disabled(!isEnabled)
                            .id(value)
                        }
                    }
                    .padding(.vertical, 34)
                }
                .frame(width: 70, height: 90)
                .clipped()
                .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .disabled(!isEnabled)
                .onAppear {
                    proxy.scrollTo(selection, anchor: .center)
                }
                .onChange(of: selection) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            Button {
                step(by: 1)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .help("Increment")
        }
    }

    private func step(by delta: Int) {
        let lower = range.lowerBound
        let count = range.count
        guard count > 0 else { return }
        let next = ((selection - lower + delta + count * 100) % count) + lower
        if next != selection {
            onSelect(next)
        }
    }
}
