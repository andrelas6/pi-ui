import SwiftUI

struct ConversationView: View {
    var body: some View {
        ContentUnavailableView(
            "No session selected",
            systemImage: "sidebar.left",
            description: Text("Pick a session from the sidebar.")
        )
    }
}
