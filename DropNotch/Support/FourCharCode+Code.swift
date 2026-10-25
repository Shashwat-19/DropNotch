import CoreServices

extension FourCharCode {
    /// A four-character code as a scripting dictionary writes it, for example "hook" for Music's suite.
    init(code: String) {
        precondition(code.utf8.count == 4, "Apple Event codes are four ASCII characters")
        self = code.utf8.reduce(0) { $0 << 8 | FourCharCode($1) }
    }
}
