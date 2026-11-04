import Testing
@testable import MDViewCore

private func render(_ markdown: String) -> String {
    HTMLRenderer.render(markdown: markdown)
}

@Suite("Lists (2.4)")
struct ListTests {
    @Test(arguments: ["-", "*", "+"])
    func bulletKinds(_ bullet: String) {
        #expect(render("\(bullet) a\n\(bullet) b\n") == "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n")
    }

    @Test func numbered() {
        #expect(render("1. a\n2. b\n") == "<ol>\n<li>a</li>\n<li>b</li>\n</ol>\n")
    }

    @Test func startNumberIsKept() {
        #expect(render("7. a\n8. b\n") == "<ol start=\"7\">\n<li>a</li>\n<li>b</li>\n</ol>\n")
    }

    @Test func startAtZero() {
        #expect(render("0. a\n").hasPrefix("<ol start=\"0\">"))
    }

    @Test func nestedFourLevels() {
        let html = render("- 1\n  - 2\n    - 3\n      - 4\n")
        #expect(html == "<ul>\n<li>1\n<ul>\n<li>2\n<ul>\n<li>3\n<ul>\n<li>4</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n</li>\n</ul>\n")
    }

    @Test func numberedInsideBulleted() {
        #expect(render("- a\n  1. x\n  2. y\n") == "<ul>\n<li>a\n<ol>\n<li>x</li>\n<li>y</li>\n</ol>\n</li>\n</ul>\n")
    }

    @Test func formattingInItems() {
        #expect(render("- **b** and `c`\n") == "<ul>\n<li><strong>b</strong> and <code>c</code></li>\n</ul>\n")
    }

    @Test func looseListKeepsParagraphs() {
        #expect(render("- a\n\n- b\n") == "<ul>\n<li><p>a</p></li>\n<li><p>b</p></li>\n</ul>\n")
    }

    @Test func blankLineInsideAnItemMakesTheListLoose() {
        #expect(render("- a\n\n  more a\n- b\n")
            == "<ul>\n<li><p>a</p>\n<p>more a</p></li>\n<li><p>b</p></li>\n</ul>\n")
    }

    @Test func paragraphAfterATightListDoesNotMakeItLoose() {
        #expect(render("- a\n- b\n\nafter\n") == "<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n<p>after</p>\n")
    }

    @Test func tightnessIsPerList() {
        // The outer list is loose; the nested one stays tight.
        let html = render("- a\n  - x\n  - y\n\n- b\n")
        #expect(html == "<ul>\n<li><p>a</p>\n<ul>\n<li>x</li>\n<li>y</li>\n</ul>\n</li>\n<li><p>b</p></li>\n</ul>\n")
    }

    @Test func listTextIsEscaped() {
        #expect(render("- <b>x</b>\n") == "<ul>\n<li>&lt;b&gt;x&lt;/b&gt;</li>\n</ul>\n")
    }
}

@Suite("Task lists (2.5)")
struct TaskListTests {
    @Test func openAndDone() {
        #expect(render("- [ ] open\n- [x] done\n") == """
            <ul class="contains-task-list">
            <li class="task-list-item"><input type="checkbox" disabled> open</li>
            <li class="task-list-item"><input type="checkbox" disabled checked> done</li>
            </ul>

            """)
    }

    @Test func capitalXCounts() {
        #expect(render("- [X] done\n").contains("disabled checked> done"))
    }

    @Test func mixedListMarksOnlyTaskItems() {
        let html = render("- [ ] task\n- plain\n")
        #expect(html.contains("<li class=\"task-list-item\"><input type=\"checkbox\" disabled> task</li>"))
        #expect(html.contains("<li>plain</li>"))
    }

    @Test func numberedTasks() {
        #expect(render("1. [x] one\n").hasPrefix("<ol class=\"contains-task-list\">"))
    }

    @Test func nestedTaskList() {
        let html = render("- [ ] parent\n  - [x] child\n")
        #expect(html.contains("disabled> parent\n<ul class=\"contains-task-list\">"))
    }

    @Test func bracketsElsewhereAreNotACheckbox() {
        #expect(render("- see [x] here\n") == "<ul>\n<li>see [x] here</li>\n</ul>\n")
    }
}
