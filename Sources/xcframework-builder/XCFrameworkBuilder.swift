
import Foundation
import ArgumentParser

#warning("improve error handling")
struct XCFrameworkBuilder: ParsableCommand {
    
    static var _commandName: String {
        "xcframework-builder"
    }
    
    /// If set prints out debugging messages and keeps the working directory where the conversion takes place
    @Flag(name: .customLong("debug"))
    private var isDebug: Bool = false
    
    /// If set deletes the original framework that was passed as the input
    @Flag
    private var deleteInputFileOnSuccess: Bool = false
    
    @Option
    private var inputPath: String
    
    @Option
    private var outputPath: String
    
    mutating func run() throws {        
        try createXCFramework(for: URL(fileURLWithPath: inputPath))
    }
    
    func createXCFramework(for originalFrameworkURL: URL) throws {
        //create working dir
        let workingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)
        
        if isDebug {
            print("working dir is located at: \(workingDir.path)")
        }
        
        // An url of the framework located in the workingDir
        let frameworkURL = workingDir.appendingPathComponent(originalFrameworkURL.lastPathComponent)
        
        // the file name of the framework bundle
        let frameworkName = originalFrameworkURL.deletingPathExtension().lastPathComponent
        
        // copy framework from originalFrameworkURL to working dir
        try FileManager.default.copyItem(atPath: originalFrameworkURL.path, toPath: frameworkURL.path)
        
        #warning("handle nested frameworks within provided framework")
        
        let lipo = Lipo(frameworkPath: frameworkURL.path)
        
        let architectures = try lipo.availableArchitectures()
        
        let architecturesByPlatform = Dictionary(grouping: architectures, by: { $0.platform })
        var frameworkOutputURLs = [URL]()
        
        for platform in architecturesByPlatform{
            // create folder with name of the platform that will contain the converted framework
            var frameworkCopyURL = workingDir.appendingPathComponent(platform.key.rawValue)
            try FileManager.default.createDirectory(at: frameworkCopyURL, withIntermediateDirectories: true, attributes: nil)
            frameworkCopyURL.appendPathComponent(frameworkName)
            frameworkCopyURL.appendPathExtension("framework")
            frameworkOutputURLs.append(frameworkCopyURL)
            
            // make copy of original input framework and place it in the architecture folder
            try FileManager.default.copyItem(at: frameworkURL, to: frameworkCopyURL)
            // remove the fat Mach-O binary from the framework copy
            try FileManager.default.removeItem(at: frameworkCopyURL.appendingPathComponent(frameworkName))
            
            // extract all platform architectures from original framework
            try lipo.extractArchitectures(platform.value, to: frameworkCopyURL.appendingPathComponent(frameworkName).path)
        }
        
        try Xcodebuild.createXCFramework(from: frameworkOutputURLs, outputURL: URL(fileURLWithPath: outputPath))
        
        if !isDebug {
            try FileManager.default.removeItem(at: workingDir)
        }
        
        if deleteInputFileOnSuccess {
            try FileManager.default.removeItem(at: originalFrameworkURL)
        }
    }
}
