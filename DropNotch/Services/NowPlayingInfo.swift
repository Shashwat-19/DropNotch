/// What a `NowPlayingSource` reports. Track details are user content: never log them.
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var isPlaying: Bool
}
