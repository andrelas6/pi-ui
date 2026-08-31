import SwiftUI

struct FileTreeView: View {
    let copy: WorkingCopy
    let branch: String?

    @State private var open: Set<String> = []
    @State private var seeded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Hairline()
            rows
            Hairline()
            footer
        }
        .background(Palette.bg)
        .onChange(of: copy.nodes) { _, nodes in
            guard !seeded, !nodes.isEmpty else { return }
            open = foldersHoldingChanges(nodes)
            seeded = true
        }
    }

    private var header: some View {
        HStack {
            Kicker(text: "files")
            Spacer()
            if copy.changed > 0 {
                Text(copy.changedText)
                    .font(Typeface.mono(11))
                    .foregroundStyle(Palette.accent(700))
            }
        }
        .padding(.horizontal, Space.four)
        .padding(.top, Space.four)
        .padding(.bottom, Space.three)
    }

    private var rows: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(visible(copy.nodes, depth: 0), id: \.node.id) { entry in
                    Row(node: entry.node, depth: entry.depth, isOpen: open.contains(entry.node.path)) {
                        toggle(entry.node)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if copy.isEmpty {
                Kicker(text: "not a git repo", size: 12, color: Palette.neutral(500))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(branch ?? "—")
                .font(Typeface.mono(11))
                .foregroundStyle(Palette.neutral(600))
                .lineLimit(1)
            Spacer()
            if !copy.tallyText.isEmpty {
                Text(copy.tallyText)
                    .font(Typeface.mono(11))
                    .foregroundStyle(Palette.accent(700))
            }
        }
        .padding(.horizontal, Space.four)
        .padding(.vertical, Space.three)
    }

    /// Only what is actually on screen: a closed folder's contents are never walked.
    private func visible(_ nodes: [FileNode], depth: Int) -> [(node: FileNode, depth: Int)] {
        nodes.flatMap { node -> [(node: FileNode, depth: Int)] in
            let row = [(node: node, depth: depth)]
            guard node.isFolder, open.contains(node.path) else { return row }
            return row + visible(node.children, depth: depth + 1)
        }
    }

    private func foldersHoldingChanges(_ nodes: [FileNode]) -> Set<String> {
        var found: Set<String> = []
        for node in nodes where node.isFolder && node.holdsAChange {
            found.insert(node.path)
            found.formUnion(foldersHoldingChanges(node.children))
        }
        return found
    }

    private func toggle(_ node: FileNode) {
        guard node.isFolder else { return }
        if open.contains(node.path) {
            open.remove(node.path)
        } else {
            open.insert(node.path)
        }
    }

    private struct Row: View {
        let node: FileNode
        let depth: Int
        let isOpen: Bool
        let tap: () -> Void

        @State private var hovering = false

        var body: some View {
            HStack(spacing: 6) {
                if node.isFolder {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.neutral(600))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 12)
                } else {
                    Color.clear.frame(width: 12)
                }

                Text(node.name)
                    .font(Typeface.mono(12))
                    .foregroundStyle(node.isFolder ? Palette.text : Palette.neutral(700))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: Space.one)

                if let badge = node.badge {
                    Text(badge)
                        .font(Typeface.mono(10))
                        .foregroundStyle(Palette.accent(800))
                        .padding(.horizontal, 3)
                        .overlay(Rectangle().stroke(Palette.accent(400), lineWidth: Frame.hairline))
                }
            }
            .padding(.leading, 8 + CGFloat(depth) * 13)
            .padding(.trailing, Space.four)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background(hovering ? Palette.accent(100) : .clear)
            .onHover { hovering = $0 }
            .onTapGesture(perform: tap)
        }
    }
}
