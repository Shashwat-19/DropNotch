import XCTest
@testable import DropNotch

final class SyncedLyricsTests: XCTestCase {
    // Made-up lines; real lyrics never go in the repo.
    private let lrc = """
    [ar:Someone]
    [ti:A song]
    [00:01.50] First line
    [00:05.00][01:05.00] Chorus line
    [00:09.123]
    [00:12] Last line
    a line without a stamp
    """

    func testParsesStampsInTimeOrderAndSkipsMetadata() throws {
        let lyrics = try XCTUnwrap(SyncedLyrics(lrc: lrc))
        XCTAssertEqual(lyrics.lines.map(\.time), [1.5, 5, 9.123, 12, 65])
        XCTAssertEqual(lyrics.lines.map(\.text), ["First line", "Chorus line", "", "Last line", "Chorus line"])
    }

    func testLineAtATimeIsTheLastOneStarted() throws {
        let lyrics = try XCTUnwrap(SyncedLyrics(lrc: lrc))
        XCTAssertNil(lyrics.line(at: 0), "before the first line")
        XCTAssertEqual(lyrics.line(at: 1.5)?.text, "First line")
        XCTAssertEqual(lyrics.line(at: 4.99)?.text, "First line")
        XCTAssertEqual(lyrics.line(at: 10)?.text, "", "an instrumental gap")
        XCTAssertEqual(lyrics.line(at: 300)?.text, "Chorus line")
        XCTAssertEqual(lyrics.starts(after: 9.123), [12, 65])
    }

    func testPlainTextIsNotSyncedLyrics() {
        XCTAssertNil(SyncedLyrics(lrc: "Just words\nwith no stamps"))
        XCTAssertNil(SyncedLyrics(lrc: "[ar:Artist]\n[xx:yy] nope\n[00:75.00] bad seconds"))
        XCTAssertNil(SyncedLyrics(lrc: ""))
    }
}

final class LRCLibClientTests: XCTestCase {
    private final class Stub: URLProtocol {
        nonisolated(unsafe) static var reply: (status: Int, body: String) = (404, "")
        nonisolated(unsafe) static var requests: [URLRequest] = []
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.requests.append(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: Self.reply.status, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(Self.reply.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    override func setUp() {
        super.setUp()
        Stub.requests = []
    }

    private func client() -> LRCLibClient { LRCLibClient(protocolClasses: [Stub.self]) }

    func testFoundSyncedLyricsAreParsedAndTheRequestCarriesOnlyTheTrack() async throws {
        Stub.reply = (200, #"{"id":1,"trackName":"Song","instrumental":false,"plainLyrics":"One","syncedLyrics":"[00:01.00] One"}"#)
        let lyrics = try await client().lyrics(title: "Song & Dance", artist: "Band", duration: 199.6)
        XCTAssertEqual(lyrics?.lines.first?.text, "One")
        let request = try XCTUnwrap(Stub.requests.first)
        XCTAssertEqual(request.url?.host(), "lrclib.net")
        XCTAssertEqual(request.url?.path(), "/api/get")
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") }),
                       ["track_name": "Song & Dance", "artist_name": "Band", "duration": "200"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), LRCLibClient.userAgent)
    }

    func testNotFoundInstrumentalOrPlainOnlyMeanNoLyrics() async throws {
        for body in [(404, #"{"message":"Failed to find specified track","name":"TrackNotFound","statusCode":404}"#),
                     (200, #"{"instrumental":true,"syncedLyrics":null}"#),
                     (200, #"{"instrumental":false,"plainLyrics":"Words","syncedLyrics":null}"#)] {
            Stub.reply = body
            let lyrics = try await client().lyrics(title: "Song", artist: "Band", duration: nil)
            XCTAssertNil(lyrics, body.1)
        }
        XCTAssertFalse(Stub.requests.last?.url?.query()?.contains("duration") ?? true, "no duration, none sent")
    }

    func testServerErrorThrows() async {
        Stub.reply = (503, "")
        do {
            _ = try await client().lyrics(title: "Song", artist: "Band", duration: 100)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(error as? ServiceError, .badResponse(status: 503))
        }
    }
}
