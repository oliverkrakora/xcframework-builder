
import Foundation
import ArgumentParser

#warning("improve error handling")
struct XCFrameworkBuilder: ParsableCommand {
    
    enum Error: Swift.Error {
        case commandNotInstalled(commandName: String)
        case invalidPath
    }
    
    static var _commandName: String {
        "xcframework-builder"
    }
    
    /// If set prints out debugging messages and keeps the working directory where the conversion takes place
    @Flag(name: .customLong("debug"))
    private var isDebug: Bool = false
    
    /// If set deletes the original framework that was passed as the input
    @Flag
    private var deleteInputFileOnSuccess: Bool = false
    
    @Option(name: .customLong("framework-input-path"))
    private var fileInputURL: URL
    
    @Option(name: .customLong("output-path"))
    private var outputURL: URL
    
    mutating func run() throws {
        try createXCFramework(for: fileInputURL)
    }
    
    func createXCFramework(for originalFrameworkURL: URL) throws {
        try createXCFramework(for: originalFrameworkURL, outputURL: outputURL, deleteInputFileOnSuccess: deleteInputFileOnSuccess, isDebug: isDebug)
    }
        
    func createXCFramework(for originalFrameworkURL: URL, outputURL: URL, deleteInputFileOnSuccess: Bool, isDebug: Bool) throws {
        
        guard !fileInputURL.pathExtension.isEmpty else {
            throw Error.invalidPath
        }
        
        guard outputURL.pathExtension.isEmpty else {
            throw Error.invalidPath
        }
                
        guard Bash.isCommandInstalled(Lipo.commandName) else {
            throw Error.commandNotInstalled(commandName: Lipo.commandName)
        }
        
        guard Bash.isCommandInstalled(Xcodebuild.commandName) else {
            throw Error.commandNotInstalled(commandName: Xcodebuild.commandName)
        }
        
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
        
        let frameworkOutputURL = workingDir.appendingPathComponent(frameworkName).appendingPathExtension("xcframework")
        
        // copy framework from originalFrameworkURL to working dir
        try FileManager.default.copyItem(atPath: originalFrameworkURL.path, toPath: frameworkURL.path)
        
        // the frameworks folder inside the framework
        let nestedFrameworksURL = frameworkURL.appendingPathComponent("Frameworks")
        
        if FileManager.default.fileExists(atPath: nestedFrameworksURL.path, isDirectory: nil) {
            let frameworks = try FileManager.default.contentsOfDirectory(at: nestedFrameworksURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants]).filter { $0.pathExtension == "framework" }
            
            for frameworkURL in frameworks {
                try createXCFramework(for: frameworkURL, outputURL: workingDir, deleteInputFileOnSuccess: false, isDebug: false)
            }
            
            try FileManager.default.removeItem(at: nestedFrameworksURL)
        }
                
        let lipo = Lipo(frameworkURL: frameworkURL)
        
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
        
        try Xcodebuild.createXCFramework(from: frameworkOutputURLs, outputURL: frameworkOutputURL)
        
        // Make sure output directory exists
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        
        // Moving xcframeworks to output directory
        
        let xcframeworkURLs = try FileManager.default.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants]).filter { $0.pathExtension == "xcframework" }

        for xcframeworkURL in xcframeworkURLs {
            try FileManager.default.moveItem(at: xcframeworkURL, to: outputURL.appendingPathComponent(xcframeworkURL.lastPathComponent))
        }
        
        // cleanup
        
        if !isDebug {
            try FileManager.default.removeItem(at: workingDir)
        }
        
        if deleteInputFileOnSuccess {
            try FileManager.default.removeItem(at: originalFrameworkURL)
        }
    }
}
