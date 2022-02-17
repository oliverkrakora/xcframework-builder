
import Foundation

/// a swift wrapper for the lipo command
struct Lipo {
    
    enum Error: Swift.Error {
        case invalidInput
        case underlying(exitCode: Int32, message: String?)
    }
    
    static let commandName = "lipo"
    
    let frameworkURL: URL?
    
    let binaryURL: URL
    
    init(frameworkURL: URL) {
        self.frameworkURL = frameworkURL
        
        //Path to Mach-O binary
        self.binaryURL = frameworkURL.appendingPathComponent(frameworkURL.deletingPathExtension().lastPathComponent)
    }
    
    init(binaryURL: URL) {
        self.frameworkURL = nil
        self.binaryURL = binaryURL
    }
    
    private func validateBinaryPath() throws {

        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw Error.invalidInput
        }
        
        guard Process.executeCommand(name: Self.commandName, arguments: [binaryURL.path, "-info"]).terminationStatus != 0 else { return }
        throw Error.invalidInput
    }
    
    func availableArchitectures() throws -> [Architecture] {
        try validateBinaryPath()
        
        let process = Process.executeCommand(name: Self.commandName, arguments: [binaryURL.path, "-archs"])
        
        guard process.terminationStatus == 0 else {
            throw Error.underlying(exitCode: process.terminationStatus, message: process.errorData())
        }
        
        let output: String? = process.outputData()
        
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .compactMap { Architecture(rawValue: String($0)) } ?? []
    }
    
    func extractArchitectures(_ architectures: [Architecture], to outputPath: String) throws {
        try validateBinaryPath()
        
        var arguments: [String] = [
            binaryURL.path
        ]
        
        arguments.append(contentsOf: ["-output", outputPath])
        
        arguments.append(contentsOf: architectures.flatMap { ["-extract", $0.rawValue] })
        
        let process = Process.executeCommand(name: Self.commandName, arguments: arguments)
        
        if process.terminationStatus != 0 {
            throw Error.underlying(exitCode: process.terminationStatus, message: process.outputData())
        }
    }
}
