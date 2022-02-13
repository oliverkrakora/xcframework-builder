//
//  File.swift
//  
//
//  Created by Oliver Krakora on 13.02.22.
//

import Foundation

extension Process {
    static func executeCommand(name: String, arguments: [String]?, pipe: Pipe? = nil) -> Process {
        let process = Process()
        process.launchPath = "/usr/bin/" + name
        process.arguments = arguments
        
        let pipe = pipe ?? Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.launch()
        process.waitUntilExit()
        
        return process
    }
    
    func outputData() -> Data? {
        guard let fileHandle = (standardOutput as? Pipe)?.fileHandleForReading ?? standardOutput as? FileHandle else { return nil }
        return fileHandle.readDataToEndOfFile()
    }
    
    func outputData() -> String? {
        outputData().flatMap { return String(data: $0, encoding: .utf8) }
    }
    
    func errorData() -> Data? {
        guard let fileHandle = (standardError as? Pipe)?.fileHandleForReading ?? standardError as? FileHandle else { return nil }
        return fileHandle.readDataToEndOfFile()
    }
    
    func erroData() -> String? {
        errorData().flatMap { return String(data: $0, encoding: .utf8) }
    }
}
