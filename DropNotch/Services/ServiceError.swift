/// Failures from DropNotch's web services, weather and lyrics (D53). Never carries a request's content.
enum ServiceError: Error, Equatable {
    case badResponse(status: Int)
    case tooLarge
    case invalidQuery
}
