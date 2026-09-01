import SwiftUI

struct ConversationView: View {
    @Bindable var chat: Chat
    @FocusState private var typing: Bool
    @State private var pickingModel = false
    @State private var pane: CGSize = .zero

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

                if chat.isStreaming {
                    ProcessingIndicator(stop: chat.stopEverything)
                }
                Divider()
                composer
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { pane = proxy.size }
                    .onChange(of: proxy.size) { _, size in pane = size }
            }
        )
        .onChange(of: chat.typingRequests) { _, _ in
            // A hop, so the box exists before the cursor is sent to it.
            DispatchQueue.main.async { typing = true }
        }
    }

    private var header: some View {
        HStack(spacing: Space.three) {
            Text(chat.folder?.lastPathComponent ?? "pi")
                .font(Typeface.heading(24, bold: true))
                .foregroundStyle(Palette.text)
                .lineLimit(1)

            if let branch = chat.branch {
                OutlineTag(text: branch)
            }

            Kicker(text: meta, size: 11, tracking: 0.12, color: Palette.neutral(600))
                .lineLimit(1)

            Spacer(minLength: Space.two)

            NotYetButton(icon: "plusminus", what: "diff")
            NotYetButton(icon: "terminal", what: "terminal")
        }
        .padding(Space.four)
    }

    /// The design shows message count and elapsed time; ours carries what pi actually
    /// reports — how full the context is and what the session has cost.
    private var meta: String {
        var parts = ["\(chat.messages.count) msgs"]
        if let stats = chat.stats {
            if let context = stats.contextText { parts.append(context) }
            if !stats.costText.isEmpty { parts.append(stats.costText) }
        }
        return parts.joined(separator: " · ")
    }

    private var transcript: some View {
        TranscriptView(messages: chat.messages) { id, choice in
            chat.answerRequest(id: id, choice: choice)
        }
    }

    private var composer: some View {
        VStack(alignment: .center, spacing: Space.two) {
            if !chat.steering.isEmpty || !chat.followUps.isEmpty {
                QueueStrip(
                    steering: chat.steering,
                    followUps: chat.followUps,
                    clear: chat.clearQueue
                )
            }

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: Space.two) {
                    Text(">")
                        .font(Typeface.mono(13))
                        .foregroundStyle(Palette.accent(700))

                    TextField(placeholder, text: $chat.draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(Typeface.body(13))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1...6)
                        .focused($typing)
                        .onSubmit(send)
                }
                .padding(.horizontal, Space.four)
                .padding(.top, Space.four)
                .padding(.bottom, Space.three)

                Hairline()

                controls
                    .padding(.horizontal, Space.three)
                    .padding(.vertical, 1)
            }
            .blueprint(fill: Palette.neutral(100))
        }
        .frame(maxWidth: composerWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, spaceAroundBar)
        .onChange(of: chat.recovered) { _, texts in
            guard !texts.isEmpty else { return }
            let back = chat.takeRecovered().joined(separator: "\n")
            chat.draft = chat.draft.isEmpty ? back : chat.draft + "\n" + back
        }
    }

    private var controls: some View {
        HStack(spacing: Space.one) {
            GhostButton(
                title: chat.modelName.isEmpty ? "model" : chat.modelName,
                icon: "shippingbox",
                trailingIcon: "chevron.down"
            ) {
                pickingModel = true
                Task { await chat.loadModels() }
            }
            .popover(isPresented: $pickingModel, arrowEdge: .top) {
                ModelPicker(
                    models: chat.models,
                    current: chat.modelName,
                    choose: { model in
                        pickingModel = false
                        Task { await chat.use(model) }
                    }
                )
            }

            if !chat.thinkingLevels.isEmpty {
                Menu {
                    ForEach(chat.thinkingLevels, id: \.self) { level in
                        Button(level) { Task { await chat.setThinking(level) } }
                    }
                } label: {
                    Kicker(
                        text: chat.thinkingLevel.isEmpty ? "thinking" : chat.thinkingLevel,
                        size: 12,
                        tracking: 0.06,
                        color: Palette.neutral(700)
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(height: 24)
                .help("How hard the model thinks before answering")
            }

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
                .controlSize(.small)
                .help("Steer interrupts the current turn. After waits until it finishes.")
            }

            Spacer(minLength: Space.two)

            NotYetButton(icon: "mic", what: "voice input")

            if chat.isStreaming {
                PrimaryButton(title: "stop", icon: "stop.fill", action: chat.stopEverything)
            } else {
                PrimaryButton(title: "send", icon: "arrow.up", enabled: canSend, action: send)
            }
        }
        .frame(height: 26)
    }

    /// Four fifths of the pane, centred, so the box does not run the full width.
    private var composerWidth: CGFloat {
        guard pane.width > 0 else { return .infinity }
        return max(pane.width * 0.8, 320)
    }

    /// Equal above and below, so the bar sits in the middle of its own band rather
    /// than riding the top of it.
    private var spaceAroundBar: CGFloat {
        guard pane.height > 0 else { return Space.four }
        return max(pane.height * 0.04, Space.four)
    }

    private var canSend: Bool {
        !chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholder: String {
        guard chat.isStreaming else { return "Ask pi…" }
        return chat.queueAsFollowUp ? "Queue for when it finishes…" : "Steer the current turn…"
    }

    private func send() {
        chat.send(chat.draft)
        chat.draft = ""
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
