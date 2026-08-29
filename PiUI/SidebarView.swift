import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
        }
        .overlay {
            ContentUnavailableView(
                "No sessions",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Create a session to get started.")
            )
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem {
                Button {
                } label: {
                    Label("New session", systemImage: "plus")
                }
                .disabled(true)
                .help("Coming in S4")
            }
        }
    }
}
