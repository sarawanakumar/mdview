import Testing
@testable import MDViewCore

@Suite("Zoom levels (6.7)")
struct ZoomLevelsTests {
    @Test func stepsInFromActualSize() {
        var zoom = 1.0
        var seen: [Double] = []
        while let next = ZoomLevels.zoomedIn(from: zoom) { seen.append(next); zoom = next }
        #expect(seen == [1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0])
        #expect(ZoomLevels.zoomedIn(from: 3.0) == nil)
    }

    @Test func stepsOutFromActualSize() {
        var zoom = 1.0
        var seen: [Double] = []
        while let next = ZoomLevels.zoomedOut(from: zoom) { seen.append(next); zoom = next }
        #expect(seen == [0.9, 0.8, 0.75, 0.67, 0.5])
        #expect(ZoomLevels.zoomedOut(from: 0.5) == nil)
    }

    @Test func inThenOutReturnsToTheStart() {
        let start = 1.25
        #expect(ZoomLevels.zoomedOut(from: ZoomLevels.zoomedIn(from: start)!) == start)
    }

    @Test func valuesBetweenStepsMoveToTheNextOne() {
        #expect(ZoomLevels.zoomedIn(from: 1.3) == 1.5)
        #expect(ZoomLevels.zoomedOut(from: 1.3) == 1.25)
    }

    @Test func actualSize() {
        #expect(ZoomLevels.isActualSize(1.0))
        #expect(ZoomLevels.isActualSize(1.0000001))
        #expect(!ZoomLevels.isActualSize(1.1))
    }
}
