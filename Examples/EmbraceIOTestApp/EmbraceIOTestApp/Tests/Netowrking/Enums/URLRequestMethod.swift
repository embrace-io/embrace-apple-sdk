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

    var text: String {
        switch self {
        case .get:
            "GET "
        case .post:
            "POST "
        case .put:
            "PUT "
        case .delete:
            "DELETE "
        }
    }
}
