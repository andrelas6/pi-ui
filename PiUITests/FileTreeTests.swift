import Foundation
import Testing

@testable import PiUI

struct GitStatusTests {
    /// The status field is two characters, then a space, then the path — so a leading
    /// space is part of the status and splitting on whitespace loses it.
    private let porcelain = """
     D gone.txt
    A  src/added.txt
     M src/app.txt
    ?? loose.txt
    """

    @Test func readsEveryChange() {
        let badges = GitStatus.badges(porcelain: porcelain)

        #expect(badges["gone.txt"] == "D")
        #expect(badges["src/added.txt"] == "A")
        #expect(badges["src/app.txt"] == "M")
        #expect(badges["loose.txt"] == "A")
        #expect(badges.count == 4)
    }

    /// A path with a space in it must survive: the path starts at column three.
    @Test func keepsPathsWithSpaces() {
        let badges = GitStatus.badges(porcelain: " M src/my file.txt")
        #expect(badges["src/my file.txt"] == "M")
    }

    @Test func takesTheNewNameOfARename() {
        let badges = GitStatus.badges(porcelain: "R  old/name.txt -> new/name.txt")
        #expect(badges["new/name.txt"] == "R")
        #expect(badges["old/name.txt"] == nil)
    }

    @Test func unquotesAnAwkwardPath() {
        let badges = GitStatus.badges(porcelain: " M \"src/oddly named.txt\"")
        #expect(badges["src/oddly named.txt"] == "M")
    }

    @Test func ignoresBlankAndShortLines() {
        #expect(GitStatus.badges(porcelain: "").isEmpty)
        #expect(GitStatus.badges(porcelain: "\n \n M\n").isEmpty)
    }

    @Test func countsInsertionsAndDeletions() {
        let tally = GitStatus.tally(shortstat: " 3 files changed, 41 insertions(+), 7 deletions(-)")
        #expect(tally.added == 41)
        #expect(tally.removed == 7)
    }

    /// git omits the half that is zero, so a missing clause is not a parse failure.
    @Test func survivesAHalfThatIsMissing() {
        let onlyAdded = GitStatus.tally(shortstat: " 1 file changed, 2 insertions(+)")
        #expect(onlyAdded.added == 2)
        #expect(onlyAdded.removed == 0)

        let onlyRemoved = GitStatus.tally(shortstat: " 1 file changed, 5 deletions(-)")
        #expect(onlyRemoved.added == 0)
        #expect(onlyRemoved.removed == 5)
    }

    /// "3 files changed" must not be mistaken for a count of insertions.
    @Test func doesNotReadTheFileCountAsAChange() {
        let tally = GitStatus.tally(shortstat: " 3 files changed")
        #expect(tally.added == 0)
        #expect(tally.removed == 0)
    }

    @Test func survivesNoChangesAtAll() {
        let tally = GitStatus.tally(shortstat: "")
        #expect(tally.added == 0)
        #expect(tally.removed == 0)
    }
}

struct FileTreeBuildTests {
    private let paths = [
        "src/settings/SettingsPanel.tsx",
        "src/settings/store.ts",
        "src/main.tsx",
        "tests/settings.spec.ts",
        "package.json",
    ]

    @Test func nestsPathsIntoFolders() {
        let tree = FileTree.build(paths: paths)
        let names = tree.map(\.name)

        #expect(names.contains("src"))
        #expect(names.contains("tests"))
        #expect(names.contains("package.json"))

        let src = tree.first { $0.name == "src" }
        #expect(src?.isFolder == true)
        #expect(src?.children.count == 2)
    }

    /// Folders lead, then files, each alphabetical — as the design draws it.
    @Test func ordersFoldersBeforeFiles() {
        let tree = FileTree.build(paths: paths)
        #expect(tree.map(\.name) == ["src", "tests", "package.json"])
    }

    @Test func marksOnlyTheFileThatChanged() {
        let tree = FileTree.build(paths: paths, badges: ["src/settings/store.ts": "M"])
        let src = tree.first { $0.name == "src" }
        let settings = src?.children.first { $0.name == "settings" }
        let store = settings?.children.first { $0.name == "store.ts" }

        #expect(store?.badge == "M")
        #expect(settings?.badge == nil)
        #expect(src?.badge == nil)
    }

    /// A folder opens by default when something inside it changed, however deep.
    @Test func knowsWhichFoldersHoldAChange() {
        let tree = FileTree.build(paths: paths, badges: ["src/settings/store.ts": "M"])
        let src = try? #require(tree.first { $0.name == "src" })

        #expect(src?.holdsAChange == true)
        #expect(tree.first { $0.name == "tests" }?.holdsAChange == false)
    }

    @Test func handlesAFlatRepository() {
        let tree = FileTree.build(paths: ["a.txt", "b.txt"])
        #expect(tree.count == 2)
        #expect(tree.allSatisfy { !$0.isFolder })
    }

    @Test func handlesNothingAtAll() {
        #expect(FileTree.build(paths: []).isEmpty)
        #expect(FileTree.build(paths: [""]).isEmpty)
    }

    @Test func doesNotDuplicateASharedFolder() {
        let tree = FileTree.build(paths: ["a/one.txt", "a/two.txt", "a/b/three.txt"])
        #expect(tree.count == 1)

        let a = tree[0]
        #expect(a.children.map(\.name) == ["b", "one.txt", "two.txt"])
    }
}

struct WorkingCopySummaryTests {
    @Test func readsTheTotalsAsTheDesignWritesThem() {
        let copy = WorkingCopy(nodes: [], changed: 3, added: 41, removed: 7)
        #expect(copy.tallyText == "+41 −7")
        #expect(copy.changedText == "3 changed")
    }

    @Test func saysNothingWhenNothingChanged() {
        #expect(WorkingCopy().tallyText.isEmpty)
    }

    @Test func countsOneChangeInTheSingular() {
        #expect(WorkingCopy(nodes: [], changed: 1).changedText == "1 changed")
    }
}
