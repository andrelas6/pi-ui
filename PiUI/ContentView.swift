import SwiftUI

struct ContentView: View {
    let shortcuts: Shortcuts

    @State private var store = SessionStore()
    @State private var pool: ChatPool?
    @State private var keys = KeyMonitor()
    @State private var showingPalette = false

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(
                appName: PiUIApp.name,
                path: pool?.current?.folder?.shortPath,
                sessionCount: store.sessions.count,
                needingInput: needingInput
            )
            Hairline()

            HStack(spacing: 0) {
                SidebarView(store: store, pool: pool, open: show, start: start)
                    .frame(width: Frame.sessionRail)

                Hairline(vertical: true)

                conversation
                    .frame(minWidth: Frame.mainMinimum, maxWidth: .infinity)

                if let chat = pool?.current {
                    Hairline(vertical: true)
                    FileTreeView(copy: chat.files, branch: chat.branch)
                        .frame(width: Frame.fileTree)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Palette.bg)
        .task {
            let pool = ChatPool(store: store)
            self.pool = pool
            keys.start(
                newSession: { startNewSession(with: pool) },
                jump: { number in
                    guard let session = store.session(at: number) else { return }
                    pool.show(session, thenType: true)
                },
                interrupt: {
                    guard let chat = pool.current, chat.isStreaming else { return }
                    chat.stopEverything()
                },
                answer: { choice in
                    guard let chat = pool.current,
                          let ask = chat.ask,
                          ask.method == .confirm
                    else { return false }
                    chat.answerRequest(id: ask.id, choice: choice)
                    return true
                },
                palette: { openPalette() }
            )
        }
        .onChange(of: shortcuts.newSessionCount) { _, _ in
            guard let pool else { return }
            startNewSession(with: pool)
        }
        .onChange(of: shortcuts.paletteCount) { _, _ in
            openPalette()
        }
        .onChange(of: shortcuts.jumpTo) { _, number in
            guard let number else { return }
            shortcuts.jumpTo = nil
            guard let session = store.session(at: number) else { return }
            pool?.show(session, thenType: true)
        }
        .sheet(isPresented: $showingPalette) {
            CommandPalette(
                commands: pool?.current?.commands ?? [],
                pick: { command in
                    showingPalette = false
                    write(command)
                },
                close: { showingPalette = false }
            )
        }
        .sheet(item: sheetBinding) { ask in
            AskSheet(
                ask: ask,
                confirm: { pool?.current?.answer(ask, confirmed: $0) },
                remember: { pool?.current?.alwaysAllow(ask) },
                submit: { pool?.current?.answer(ask, value: $0) },
                cancel: { pool?.current?.dismiss(ask) }
            )
        }
    }

    @ViewBuilder
    private var conversation: some View {
        if let chat = pool?.current {
            ConversationView(chat: chat)
        } else {
            VStack(spacing: Space.three) {
                Kicker(text: "no session open", size: 13, tracking: 0.14)
                Text("Press ⌃T, or use the + button, to pick a folder.")
                    .font(Typeface.body(13))
                    .foregroundStyle(Palette.neutral(600))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var needingInput: Int {
        guard let pool else { return 0 }
        return store.sessions.filter { pool.isWaiting($0.id) }.count
    }

    /// A confirm is answered in the transcript; select, input and editor still need
    /// somewhere to go.
    private var sheetBinding: Binding<Ask?> {
        Binding(
            get: {
                guard let ask = pool?.current?.ask, ask.method != .confirm else { return nil }
                return ask
            },
            set: { _ in }
        )
    }

    private func openPalette() {
        guard let chat = pool?.current else { return }
        showingPalette = true
        Task { await chat.loadCommands() }
    }

    /// Written into the box rather than sent: most commands take an argument, and
    /// firing one blind is not recoverable.
    private func write(_ command: PiCommand) {
        guard let chat = pool?.current else { return }
        let invocation = "/\(command.name) "
        chat.draft = chat.draft.isEmpty ? invocation : chat.draft + " " + invocation
        chat.askToType()
    }

    private func start(_ folder: URL) {
        pool?.startNew(in: folder)
    }

    private func startNewSession(with pool: ChatPool) {
        guard let folder = FolderPicker.pick() else { return }
        pool.startNew(in: folder)
    }

    private func show(_ saved: SavedSession) {
        pool?.show(saved)
    }
}
