import SwiftUI

struct ConversationView: View {
    let chat: Chat
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            if let problem = chat.problem {
                ProblemBanner(text: problem)
            }

            if chat.isOpen || !chat.messages.isEmpty {
                transcript
                Divider()
                composer
            } else {
                ContentUnavailableView(
                    "No session open",
                    systemImage: "sidebar.left",
                    description: Text("Use the + button to pick a folder.")
                )
            }
        }
        .navigationTitle(chat.folder?.lastPathComponent ?? "pi")
    }

    private var transcript: some View {
        TranscriptView(messages: chat.messages)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Ask pi…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .onSubmit(send)

            if chat.isStreaming {
                Button("Stop", systemImage: "stop.fill", action: chat.stop)
                    .labelStyle(.iconOnly)
                    .help("Abort the current turn")
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                    .labelStyle(.iconOnly)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
    }

    private func send() {
        chat.send(draft)
        draft = ""
    }
}

private struct ProblemBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.12))
    }
}
