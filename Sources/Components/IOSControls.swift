// IOSControls.swift — segmented control + toggle in the app's dark style.

import SwiftUI

/// A compact segmented control (the design's `SegSmall`): pill background,
/// accent-filled selected segment. Generic over a `Hashable` option type.
public struct IOSSegmented<Option: Hashable>: View {
    @Environment(\.theme) private var theme
    private let options: [Option]
    private let titles: (Option) -> String
    @Binding private var selection: Option

    /// - Parameters:
    ///   - options: ordered segment values.
    ///   - selection: bound selected value.
    ///   - title: maps an option to its label.
    public init(options: [Option],
                selection: Binding<Option>,
                title: @escaping (Option) -> String) {
        self.options = options
        self._selection = selection
        self.titles = title
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { opt in
                let on = opt == selection
                Text(titles(opt))
                    .font(Theme.sans(12.5, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Theme.ink3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: theme.r(7), style: .continuous)
                            .fill(on ? theme.accent.withA(0.95) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = opt }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: theme.r(9), style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }
}

/// iOS-style toggle (44×26 track, 22pt knob). iOS-green when on.
public struct IOSToggle: View {
    @Binding private var isOn: Bool

    public init(isOn: Binding<Bool>) { self._isOn = isOn }

    public var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Theme.iosGreen : Color.white.opacity(0.2))
                .frame(width: 44, height: 26)
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                .padding(2)
        }
        .frame(width: 44, height: 26)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isOn.toggle() }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var unit: MeasureUnit = .metric
        @State var on = true
        var body: some View {
            ZStack {
                Theme.screenBG
                VStack(spacing: 24) {
                    IOSSegmented(options: MeasureUnit.allCases, selection: $unit) { $0.title }
                    IOSToggle(isOn: $on)
                }
            }
            .environment(\.theme, Theme(accent: AccentOption.blue.color))
            .frame(width: 402, height: 240)
        }
    }
    return Demo()
}
