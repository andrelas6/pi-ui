import SwiftUI

/// Shows a popover matching files in the working copy for `@filename` search.
struct FilePicker: View {
    let files: [String]
    let query: String
    let pick: (String) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Kicker(text: "files", size: 12, color: Palette.neutral(700))
                Spacer()
                Text("\(found.count)")
                    .font(Typeface.mono(11))
                    .foregroundStyle(Palette.neutral(500))
            }
            .padding(.horizontal, Space.four)
            .padding(.top, Space.four)
            .padding(.bottom, Space.two)

            Hairline()

            if found.isEmpty {
                empty
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(found.enumerated()), id: \.element) { index, file in
                                Row(file: file, isSelected: index == selection) { pick(file) }
                                    .id(index)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: selection) { _, new in
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 420)
        .blueprint(fill: Palette.neutral(100))
        .onExitCommand(perform: close)
        .background {
            // Invisible capture for keyboard navigation
            ArrowsMonitor(up: up, down: down, enter: enter)
        }
        .onChange(of: query) { _, _ in
            selection = 0
        }
    }

    @State private var selection = 0

    private var found: [String] {
        let lower = query.lowercased()
        // If exact prefix or contains
        return files.filter { $0.lowercased().contains(lower) }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Space.two) {
            Text("No files found.")
                .font(Typeface.body(13))
                .foregroundStyle(Palette.text)
        }
        .padding(Space.four)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func up() {
        guard selection > 0 else { return }
        selection -= 1
    }

    private func down() {
        guard selection < found.count - 1 else { return }
        selection += 1
    }

    private func enter() {
        guard found.indices.contains(selection) else { return }
        pick(found[selection])
    }

    private struct Row: View {
        let file: String
        let isSelected: Bool
        let run: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: run) {
                HStack(alignment: .firstTextBaseline, spacing: Space.two) {
                    Text(file)
                        .font(Typeface.mono(12))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: Space.two)
                }
                .padding(.horizontal, Space.four)
                .padding(.vertical, Space.two)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected || hovering ? Palette.accent(100) : .clear)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}
