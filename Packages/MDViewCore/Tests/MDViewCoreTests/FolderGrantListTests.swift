import Testing
@testable import MDViewCore

@Suite("Folder grants (9.5, 9.6)")
struct FolderGrantListTests {
    @Test func coversTheFolderAndEverythingInside() {
        let grants = FolderGrantList(folders: ["/Users/me/Notes"])
        #expect(grants.covers("/Users/me/Notes"))
        #expect(grants.covers("/Users/me/Notes/a.md"))
        #expect(grants.covers("/Users/me/Notes/deep/down/img.png"))
    }

    @Test func doesNotCoverNeighboursOrParents() {
        let grants = FolderGrantList(folders: ["/Users/me/Notes"])
        #expect(!grants.covers("/Users/me/Notes2/a.md"))
        #expect(!grants.covers("/Users/me/Note"))
        #expect(!grants.covers("/Users/me"))
        #expect(!grants.covers("/Users/me/Other/a.md"))
    }

    @Test func trailingSlashesDontMatter() {
        let grants = FolderGrantList(folders: ["/Users/me/Notes/"])
        #expect(grants.folders == ["/Users/me/Notes"])
        #expect(grants.covers("/Users/me/Notes/"))
    }

    @Test func alreadyCoveredFolderIsNotAdded() {
        var grants = FolderGrantList(folders: ["/Users/me"])
        let added = grants.add("/Users/me/Notes")
        #expect(!added)
        #expect(grants.folders == ["/Users/me"])
    }

    @Test func folderAboveExistingGrantsReplacesThem() {
        var grants = FolderGrantList(folders: ["/Users/me/Notes", "/Users/me/Work", "/Other"])
        let added = grants.add("/Users/me")
        #expect(added)
        #expect(grants.folders == ["/Other", "/Users/me"])
    }

    @Test func separateFoldersAreBothKept() {
        var grants = FolderGrantList()
        grants.add("/a/b")
        grants.add("/c/d")
        #expect(grants.folders == ["/a/b", "/c/d"])
    }

    @Test func rootCoversEverything() {
        let grants = FolderGrantList(folders: ["/"])
        #expect(grants.covers("/anything/at/all"))
    }

    @Test func emptyListCoversNothing() {
        #expect(!FolderGrantList().covers("/a"))
    }
}
