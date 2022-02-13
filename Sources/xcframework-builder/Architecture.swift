
import Foundation

enum Architecture: String {
    case arm64
    case arm64e
    case i386
    case x86_64
    
    var platform: Platform {
        switch self {
        case .arm64: return .iOS
        case .i386, .x86_64: return .simulator
        case .arm64e: return .mac
        }
    }
}

enum Platform: String, CaseIterable {
    case iOS
    case simulator
    case mac
}
