import SwiftUI

struct ConversationView: View {
    let chat: Chat
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var pickingModel = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()

            if let problem = chat.problem {
                Banner(text: problem, icon: "exclamationmark.triangle.fill", tint: .red)
            }

            if let notice = chat.notice {
                Banner(text: notice, icon: "info.circle.fill", tint: .blue)
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
        .sheet(isPresented: $pickingModel) {
            ModelPicker(
                models: chat.models,
                current: chat.modelName,
                choose: { model in
                    pickingModel = false
                    Task { await chat.use(model) }
                },
                cancel: { pickingModel = false }
            )
        }
        .onChange(of: chat.typingRequests) { _, _ in
            // A hop, so the box exists before the cursor is sent to it.
            DispatchQueue.main.async { typing = true }
        }
    }

    /// Plain for now: S24 rebuilds this as the design's header, with the session name,
    /// the branch tag and the icon buttons.
    private var header: some View {
        HStack(spacing: Space.three) {
            Text(chat.folder?.lastPathComponent ?? "pi")
                .font(Typeface.heading(20, bold: true))
                .foregroundStyle(Palette.text)

            Spacer()

            if let stats = chat.stats {
                StatsReadout(stats: stats)
            }

            if !chat.thinkingLevels.isEmpty {
                Menu(chat.thinkingLevel.isEmpty ? "thinking" : chat.thinkingLevel) {
                    ForEach(chat.thinkingLevels, id: \.self) { level in
                        Button(level) {
                            Task { await chat.setThinking(level) }
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("How hard the model thinks before answering")
            }

            Button(chat.modelName.isEmpty ? "Model" : chat.modelName) {
                pickingModel = true
                Task { await chat.loadModels() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.neutral(700))
            .help("Switch the model for this session")
        }
        .font(Typeface.body(12))
        .padding(Space.four)
    }

    private var transcript: some View {
        TranscriptView(messages: chat.messages)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !chat.steering.isEmpty || !chat.followUps.isEmpty {
                QueueStrip(
                    steering: chat.steering,
                    followUps: chat.followUps,
                    clear: chat.clearQueue
                )
            }

            HStack(spacing: 8) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($typing)
                    .onSubmit(send)

                if chat.isStreaming {
                    Picker("", selection: Binding(
                        get: { chat.queueAsFollowUp },
                        set: { chat.queueAsFollowUp = $0 }
                    )) {
                        Text("Steer").tag(false)
                        Text("After").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .help("Steer interrupts the current turn. After waits until it finishes.")

                    Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                        .labelStyle(.iconOnly)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Stop", systemImage: "stop.fill", action: chat.stopEverything)
                        .labelStyle(.iconOnly)
                        .help("Stop the turn and drop anything queued")
                } else {
                    Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                        .labelStyle(.iconOnly)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(12)
        .onChange(of: chat.recovered) { _, texts in
            guard !texts.isEmpty else { return }
            let back = chat.takeRecovered().joined(separator: "\n")
            draft = draft.isEmpty ? back : draft + "\n" + back
        }
    }

    private var placeholder: String {
        guard chat.isStreaming else { return "Ask pi…" }
        return chat.queueAsFollowUp ? "Queue for when it finishes…" : "Steer the current turn…"
    }

    private func send() {
        chat.send(draft)
        draft = ""
    }
}

private struct StatsReadout: View {
    let stats: SessionStats

    var body: some View {
        HStack(spacing: 6) {
            if let context = stats.contextText {
                Text(context)
                    .foregroundStyle(stats.isTight ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .help("Context window used")
            }
            if !stats.costText.isEmpty {
                Text(stats.costText)
                    .foregroundStyle(.secondary)
                    .help("Spent on this session")
            }
        }
        .font(.caption)
        .monospacedDigit()
    }
}

private struct QueueStrip: View {
    let steering: [String]
    let followUps: [String]
    let clear: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(steering, id: \.self) { text in
                    Chip(label: "steer", text: text)
                }
                ForEach(followUps, id: \.self) { text in
                    Chip(label: "after", text: text)
                }
            }
            Spacer()
            Button("Clear", action: clear)
                .buttonStyle(.link)
                .help("Drop the queued messages and put them back in the box")
        }
    }
}

private struct Chip: View {
    let label: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            Text(text)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
    }
}

private struct Banner: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
    }
}
