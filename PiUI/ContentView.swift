import SwiftUI

struct ContentView: View {
    @State private var chat = Chat()

    var body: some View {
        NavigationSplitView {
            SidebarView(chat: chat)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 380)
        } detail: {
            ConversationView(chat: chat)
        }
    }
}
