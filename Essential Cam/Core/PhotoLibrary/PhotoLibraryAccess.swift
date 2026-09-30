import Foundation

protocol PhotoLibraryReading: Sendable {
    func latestThumbnails(limit: Int) async -> [PhotoLibraryThumbnail]
}

protocol PhotoLibraryAuthorizationProviding: Sendable {
    func addAuthorizationStatus() async -> PhotoLibraryAuthorizationStatus
}

enum PhotoLibraryAuthorizationStatus: Sendable {
    case authorized
    case denied
    case notDetermined
}
