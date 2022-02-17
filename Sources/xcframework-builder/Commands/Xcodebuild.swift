//
//  File.swift
//  
//
//  Created by Oliver Krakora on 16.02.22.
//

import Foundation

struct Xcodebuild {
    
    static let commandName = "xcodebuild"
    
    enum Error: Swift.Error {
        case underlying(exitCode: Int32, message: String?)
    }
    
    private init() {}
    
    static func createXCFramework(from urls: [URL], outputURL: URL) throws {
        var arguments = [
            "-create-xcframework",
            "-output",
            outputURL.path
        ]
        
        arguments.append(contentsOf: urls.flatMap { ["-framework", $0.path] })
        
        let process = Process.executeCommand(name: Self.commandName, arguments: arguments)
        
        guard process.terminationStatus == 0 else {
            throw Error.underlying(exitCode: process.terminationStatus, message: process.errorData())
        }
    }
}
