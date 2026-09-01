import SwiftUI

/// Everything pi will answer to, in one list. Picking one writes it into the composer
/// rather than sending it, because most of them take an argument.
struct CommandPalette: View {
    let commands: [PiCommand]
    let pick: (PiCommand) -> Void
    let close: () -> Void

    @State private var search = ""
    @FocusState private var searching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Kicker(text: "commands", size: 12, color: Palette.neutral(700))
                Spacer()
                Text("\(found.count)")
                    .font(Typeface.mono(11))
                    .foregroundStyle(Palette.neutral(500))
            }
            .padding(.horizontal, Space.four)
            .padding(.top, Space.four)
            .padding(.bottom, Space.two)

            HStack(spacing: Space.two) {
                Text("/")
                    .font(Typeface.mono(13))
                    .foregroundStyle(Palette.accent(700))
                TextField("Search skills, templates and commands", text: $search)
                    .textFieldStyle(.plain)
                    .font(Typeface.body(13))
                    .focused($searching)
                    .onSubmit { if let first = found.first { pick(first) } }
            }
            .padding(.horizontal, Space.four)
            .padding(.bottom, Space.three)

            Hairline()

            if commands.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(found) { command in
                            Row(command: command) { pick(command) }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 520)
        .blueprint(fill: Palette.neutral(100))
        .onAppear { searching = true }
        .onExitCommand(perform: close)
    }

    private var found: [PiCommand] {
        commands.filter { $0.matches(search) }
    }

    /// pi finds skills on its own; the app cannot add them, so say where they live.
    private var empty: some View {
        VStack(alignment: .leading, spacing: Space.two) {
            Text("Nothing to run yet.")
                .font(Typeface.body(13))
                .foregroundStyle(Palette.text)
            Text("pi picks up skills from ~/.pi/agent/skills, prompt templates from\n~/.pi/agent/prompts, and commands from installed extensions.")
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.neutral(600))
        }
        .padding(Space.four)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct Row: View {
        let command: PiCommand
        let run: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: run) {
                HStack(alignment: .firstTextBaseline, spacing: Space.two) {
                    Text("/\(command.title)")
                        .font(Typeface.mono(12))
                        .foregroundStyle(Palette.text)

                    Text(command.detail)
                        .font(Typeface.body(12))
                        .foregroundStyle(Palette.neutral(600))
                        .lineLimit(1)

                    Spacer(minLength: Space.two)

                    Kicker(text: command.kind, size: 10, tracking: 0.1, color: Palette.neutral(500))
                }
                .padding(.horizontal, Space.four)
                .padding(.vertical, Space.two)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(hovering ? Palette.accent(100) : .clear)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}
