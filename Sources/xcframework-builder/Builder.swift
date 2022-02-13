
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
        try createXCFramework(for: inputPath)
    }
    
    func createXCFramework(for path: String) throws {

        let lipo = Lipo(frameworkPath: path)
        
        let architectures = try lipo.availableArchitectures()
        
        let workingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        if verbose {
            print("working dir is located at: \(workingDir.path)")
        }
        
        let architecturesByPlatform = Dictionary(grouping: architectures, by: { $0.platform })
                
        for platform in architecturesByPlatform {
            let outputURL = workingDir.appendingPathComponent(platform.key.rawValue)
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
            try lipo.extractArchitectures(platform.value, to: outputURL.path)
        }
    }
}
