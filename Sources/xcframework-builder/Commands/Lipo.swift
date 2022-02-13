
import Foundation

struct Lipo {
    
    enum Error: Swift.Error {
        case invalidInput
        case underlying(exitCode: Int32, message: String?)
    }
    
    private static let commandName = "lipo"
    
    let frameworkPath: String?
    
    let binaryPath: String
    
    init(frameworkPath: String) {
        self.frameworkPath = frameworkPath
        
        //Path to Mach-O binary
        self.binaryPath = {
            let url = URL(fileURLWithPath: frameworkPath)
            return url.appendingPathComponent(url.deletingPathExtension().lastPathComponent).path
        }()
    }
    
    init(binaryPath: String) {
        self.frameworkPath = nil
        self.binaryPath = binaryPath
    }
    
    private func validateBinaryPath() throws {

        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw Error.invalidInput
        }
        
        guard Process.executeCommand(name: Self.commandName, arguments: [binaryPath, "-info"]).terminationStatus != 0 else { return }
        throw Error.invalidInput
    }
    
    func availableArchitectures() throws -> [Architecture] {
        try validateBinaryPath()
        
        let process = Process.executeCommand(name: Self.commandName, arguments: [binaryPath, "-archs"])
        
        guard process.terminationStatus == 0 else {
            throw Error.underlying(exitCode: process.terminationStatus, message: process.erroData())
        }
        
        let output: String? = process.outputData()
        
        return output?.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .compactMap { Architecture(rawValue: String($0)) } ?? []
    }
    
    func extractArchitectures(_ architectures: [Architecture], to outputPath: String) throws {
        try validateBinaryPath()
        
        var arguments: [String] = [
            binaryPath
        ]
        
        arguments.append(contentsOf: ["-output", outputPath])
        
        arguments.append(contentsOf: architectures.flatMap { ["-extract", $0.rawValue] })
        
        let process = Process.executeCommand(name: Self.commandName, arguments: arguments)
        
        if process.terminationStatus != 0 {
            throw Error.underlying(exitCode: process.terminationStatus, message: process.outputData())
        }
    }
}
