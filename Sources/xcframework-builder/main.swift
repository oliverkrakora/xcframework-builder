
import Foundation
import ArgumentParser

struct Builder: ParsableCommand {
    
    enum Error: Swift.Error {
        case invalidInput
        case underlying(command: String, exitCode: Int32)
    }
    
    @Flag
    private var verbose: Bool = false
    
    @Option
    private var inputPath: String
    
    @Option
    private var outputPath: String
    
    mutating func run() throws {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw Error.invalidInput
        }
        
        try createXCFramework(for: inputPath)
    }
    
    func createXCFramework(for path: String) throws {
        //Path to Mach-O binary
        let binaryPath: String = {
            let url = URL(fileURLWithPath: inputPath)
            return url.appendingPathComponent(url.deletingPathExtension().lastPathComponent).path
        }()
        
        var exitCode: Int32 = 0
        var architectures: [Architecture]? = nil
        
        //verify that the provided path contains a valid Mach-O binary
        exitCode = executeCommand(name: "lipo", arguments: ["-archs", binaryPath]) { output in
            guard exitCode == 0 else { return }
            let data = output.readDataToEndOfFile()
            guard let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            architectures = line.split(separator: " ").compactMap { Architecture(rawValue: String($0)) }
        }
        
        guard exitCode == 0, let architectures = architectures else {
            throw Error.invalidInput
        }
        
        let workingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        if verbose {
            print("Created working dir at: \(workingDir.path)")
        }
        
        let architecturesByPlatform = Dictionary(grouping: architectures, by: { $0.platform })
                
        for platform in architecturesByPlatform {
            var arguments = [
                binaryPath
            ]
            
            let outputPath = workingDir.appendingPathComponent(platform.key.rawValue).path
            
            #warning("throw error")
            try? FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true, attributes: nil)
            
            arguments.append(contentsOf: ["-output", outputPath])
            arguments.append(contentsOf: platform.value.flatMap { ["-extract", $0.rawValue] })
            
            exitCode = executeCommand(name: "lipo", arguments: arguments, nil)
            guard exitCode == 0 else {
                throw Error.underlying(command: "lipo", exitCode: exitCode)
            }
        }
    }
}


// MARK: Helpers
extension Builder {    
    func executeCommand(name: String, arguments: [String]?, _ output: ((FileHandle) -> Void)?) -> Int32 {
        let process = Process()
        process.launchPath = "/usr/bin/" + name
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.launch()
        process.waitUntilExit()
        
        if let output = output {
            output(pipe.fileHandleForReading)
        }
        
        return process.terminationStatus
    }
}

Builder.main()
