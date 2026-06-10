// GroupedList.swift — dark grouped-list scaffolding shared by History & Settings.
//
// Direct port of the design's `DList` / `DRow` (support.jsx). These are
// Library-local helpers (not part of the shared Components surface) — they
// compose the documented `Icon` atom + `Theme` tokens, never re-style them.
//
//   • DListSection: uppercase header + rounded translucent container that clips
//     its rows so the per-row hairline dividers read as a single grouped card.
//   • DRow: leading rounded icon tile, title + optional subtitle, optional mono
//     detail value, and a trailing accessory (chevron / toggle / segmented).

import SwiftUI

/// A grouped-list section: uppercase header above a rounded, hairline-bordered
/// container that vertically stacks `DRow`s and clips them to the radius.
struct DListSection<Content: View>: View {
    @Environment(\.theme) private var theme
    let header: String?
    @ViewBuilder var content: () -> Content

    init(header: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                Text(header.uppercased())
                    .font(Theme.sans(12))
                    .tracking(0.4)
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 6)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: theme.r(16), style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.r(16), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.r(16), style: .continuous))
        }
    }
}

/// A single grouped-list row. The trailing `accessory` slot holds a chevron,
/// toggle, or segmented control. `last` suppresses the bottom hairline.
struct DRow<Accessory: View>: View {
    @Environment(\.theme) private var theme

    let icon: String?
    /// Override fill for the icon tile (e.g. solid purple/amber). When `nil`,
    /// uses `accentSoft` behind an accent-tinted glyph (matching the source).
    let iconBackground: Color?
    let title: String
    let subtitle: String?
    /// Mono detail value rendered before the accessory (e.g. a measurement).
    let detail: String?
    let last: Bool
    let action: (() -> Void)?
    @ViewBuilder var accessory: () -> Accessory

    init(icon: String? = nil,
         iconBackground: Color? = nil,
         title: String,
         subtitle: String? = nil,
         detail: String? = nil,
         last: Bool = false,
         action: (() -> Void)? = nil,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.icon = icon
        self.iconBackground = iconBackground
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.last = last
        self.action = action
        self.accessory = accessory
    }

    var body: some View {
        let row = HStack(spacing: 12) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.r(9), style: .continuous)
                        .fill(iconBackground ?? theme.accent.withA(0.18))
                    Icon(icon, size: 18, weight: 1.9,
                         color: iconBackground == nil ? theme.accent : .white)
                }
                .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.sans(15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.sans(12.5))
                        .foregroundStyle(Theme.ink3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let detail {
                Text(detail)
                    .font(Theme.mono(14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            accessory()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

/// The design's trailing chevron accessory (ink3, 16pt).
struct Chevron: View {
    var body: some View {
        Icon("chevron", size: 16, weight: 2, color: Theme.ink3)
    }
}
