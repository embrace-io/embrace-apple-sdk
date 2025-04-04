//
//  URLRequestMethod.swift
//  EmbraceIOTestApp
//
//

enum URLRequestMethod: Int, CaseIterable {
    case get
    case post
    case put
    case delete

    var description: String {
        switch self {
        case .get:
            "GET"
        case .post:
            "POST"
        case .put:
            "PUT"
        case .delete:
            "DELETE"
        }
    }

    func description(withApi api: String) -> String {
        "\(description) \(api)"
    }

    var identifier: String {
        switch self {
        case .get:
            return "URLRequestMethod_Get"
        case .post:
            return "URLRequestMethod_Post"
        case .put:
            return "URLRequestMethod_Put"
        case .delete:
            return "URLRequestMethod_Delete"
        }
    }
}
