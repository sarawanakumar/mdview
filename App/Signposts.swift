import OSLog

/// Points of interest for "double-click to first paint" (spec section 8).
/// Visible in Instruments and with `log show --signpost`.
///
/// Events: appLaunched, launchFinished, previewReady, spareReady,
/// documentRead, documentRendered, documentVisible.
enum Signposts {
    nonisolated static let signposter = OSSignposter(
        subsystem: "com.inferly.mdview", category: .pointsOfInterest
    )
}
