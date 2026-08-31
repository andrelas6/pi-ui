import SwiftUI

struct AskSheet: View {
    let ask: Ask
    let confirm: (Bool) -> Void
    let remember: () -> Void
    let submit: (String) -> Void
    let cancel: () -> Void

    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch ask.method {
            case .confirm:
                EmptyView()
            case .select:
                options
            case .input:
                TextField(ask.placeholder, text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { submit(typed) }
            case .editor:
                TextEditor(text: $typed)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .border(.separator)
            }

            buttons
        }
        .padding(18)
        .frame(minWidth: 420, maxWidth: 520)
        .onAppear { typed = ask.prefill }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text(ask.method == .confirm ? "Allow \(ask.title)?" : ask.title)
                    .font(.headline)
            }
            if !ask.message.isEmpty {
                Text(ask.message)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(ask.options, id: \.self) { option in
                Button(option) { submit(option) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack {
            Spacer()
            switch ask.method {
            case .confirm:
                Button("Deny", role: .destructive) { confirm(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Always in this session", action: remember)
                    .help("Stop asking for \(ask.title) until this session closes")
                Button("Allow") { confirm(true) }
                    .keyboardShortcut(.defaultAction)
            case .select:
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
            case .input, .editor:
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Send") { submit(typed) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct WaitingDot: View {
    @State private var faded = false

    var body: some View {
        Circle()
            .fill(.orange)
            .frame(width: 7, height: 7)
            .opacity(faded ? 0.25 : 1)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: faded)
            .onAppear { faded = true }
            .help("pi is waiting on you")
    }
}
