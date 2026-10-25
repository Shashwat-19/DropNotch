import XCTest
@testable import DropNotch

/// Offline: every request is answered by `Stub`, never the network.
final class ArtworkDownloaderTests: XCTestCase {
    private final class Stub: URLProtocol {
        static var status = 200
        static var headers: [String: String] = ["Content-Type": "image/jpeg"]
        static var body = Data([0xFF, 0xD8, 0xFF, 0xE0])
        static var requests = 0

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            Self.requests += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1",
                                           headerFields: Self.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private let downloader = ArtworkDownloader(protocolClasses: [Stub.self])
    private let good = URL(string: "https://i.scdn.co/image/ab67616d0000b273")!

    override func setUp() {
        Stub.status = 200
        Stub.headers = ["Content-Type": "image/jpeg"]
        Stub.body = Data([0xFF, 0xD8, 0xFF, 0xE0])
        Stub.requests = 0
    }

    func testOnlyHTTPSToTheExactHostIsAllowed() {
        XCTAssertTrue(ArtworkDownloader.allows(good))
        XCTAssertTrue(ArtworkDownloader.allows(URL(string: "https://I.SCDN.CO:443/image/x")!))
        for bad in ["http://i.scdn.co/image/x", "https://i.scdn.co.example.com/image/x",
                    "https://i.scdn.co@example.com/image/x", "https://user:pw@i.scdn.co/image/x",
                    "https://i.scdn.co:8443/image/x", "https://example.com/i.scdn.co", "file:///etc/hosts"] {
            XCTAssertFalse(ArtworkDownloader.allows(URL(string: bad)!), bad)
        }
    }

    func testADisallowedURLIsNeverRequested() async {
        let data = await downloader.data(from: URL(string: "https://example.com/image")!)
        XCTAssertNil(data)
        XCTAssertEqual(Stub.requests, 0)
    }

    func testAnImageIsReturned() async {
        let data = await downloader.data(from: good)
        XCTAssertEqual(data, Data([0xFF, 0xD8, 0xFF, 0xE0]))
        XCTAssertEqual(Stub.requests, 1)
    }

    func testAnythingButA200ImageIsRefused() async {
        Stub.status = 404
        var data = await downloader.data(from: good)
        XCTAssertNil(data, "status")
        Stub.status = 302
        data = await downloader.data(from: good)
        XCTAssertNil(data, "a redirect response")
        Stub.status = 200
        Stub.headers = ["Content-Type": "text/html"]
        data = await downloader.data(from: good)
        XCTAssertNil(data, "type")
    }

    func testTheSizeCapHoldsWhateverTheServerClaims() async {
        Stub.body = Data(count: ArtworkDownloader.maxBytes + 1)
        var data = await downloader.data(from: good)
        XCTAssertNil(data, "no length given")
        Stub.headers = ["Content-Type": "image/png", "Content-Length": "10"]
        data = await downloader.data(from: good)
        XCTAssertNil(data, "a length that lies")
        Stub.body = Data(count: ArtworkDownloader.maxBytes)
        Stub.headers = ["Content-Type": "image/png"]
        data = await downloader.data(from: good)
        XCTAssertEqual(data?.count, ArtworkDownloader.maxBytes, "exactly the cap is fine")
    }

    func testNothingIsStoredBetweenRequests() {
        let configuration = ArtworkDownloader().session.configuration
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 10)
        XCTAssertFalse(configuration.waitsForConnectivity)
    }

    func testRedirectsAreRefused() {
        let refuser = RedirectRefuser()
        let response = HTTPURLResponse(url: good, statusCode: 302, httpVersion: nil, headerFields: nil)!
        var followed: URLRequest? = URLRequest(url: good)
        refuser.urlSession(URLSession.shared, task: URLSession.shared.dataTask(with: good), willPerformHTTPRedirection: response,
                           newRequest: URLRequest(url: URL(string: "https://example.com/")!)) { followed = $0 }
        XCTAssertNil(followed)
    }
}
