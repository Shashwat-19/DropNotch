import Foundation

/// Fetches artwork bytes over the network (D25). A protocol so tests never touch the network.
protocol ArtworkLoading: Sendable {
    /// The image bytes, or nil for a URL that isn't allowed or for any failure.
    func data(from url: URL) async -> Data?
}
