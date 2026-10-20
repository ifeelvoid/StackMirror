import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    case missingCredential(String)
    case missingData

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .http(let code, let message): "HTTP \(code): \(message)"
        case .missingCredential(let label): "\(label) is missing. Open Settings."
        case .missingData: "The API response did not contain the expected data."
        }
    }
}
