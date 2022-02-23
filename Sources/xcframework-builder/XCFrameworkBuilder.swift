
import Foundation
import ArgumentParser

#warning("improve error handling")
struct XCFrameworkBuilder: ParsableCommand {
    
    enum Error: Swift.Error {
        case commandNotInstalled(commandName: String)
        case invalidPath
    }
    
    static var _commandName: String {
        "builder"
    }
    
    /// If set prints out debugging messages and keeps the working directory where the conversion takes place
    @Flag(name: .customLong("verbose"))
    private var isVerbose: Bool = false
    
    @Flag
    private var ignoreNestedFrameworks: Bool = false
    
    @Option(name: .customLong("framework-input-path"))
    private var fileInputURL: URL
    
    @Option(name: .customLong("output-path"))
    private var outputURL: URL
    
    mutating func run() throws {
        try createXCFramework(for: fileInputURL)
    }
    
    func createXCFramework(for originalFrameworkURL: URL) throws {
        try createXCFramework(for: originalFrameworkURL, outputURL: outputURL, isVerbose: isVerbose)
    }
        
    func createXCFramework(for originalFrameworkURL: URL, outputURL: URL, isVerbose: Bool) throws {
        
        // make sure that the input url points to a framework
        guard fileInputURL.pathExtension == "framework" else {
            throw Error.invalidPath
        }
        
        // make sure the output url points to a directory
        guard outputURL.pathExtension.isEmpty else {
            throw Error.invalidPath
        }
        
        // make sure lipo is installed
        guard Bash.isCommandInstalled(Lipo.commandName) else {
            throw Error.commandNotInstalled(commandName: Lipo.commandName)
        }
        
        // make sure xcodebuild is installed
        guard Bash.isCommandInstalled(Xcodebuild.commandName) else {
            throw Error.commandNotInstalled(commandName: Xcodebuild.commandName)
        }
        
        // create working dir
        let workingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)
        
        log("working dir is located at: \(workingDir.path)")
        
        // An url of the framework located in the workingDir
        let frameworkURL = workingDir.appendingPathComponent(originalFrameworkURL.lastPathComponent)
        
        // copy framework from originalFrameworkURL to working dir
        try FileManager.default.copyItem(atPath: originalFrameworkURL.path, toPath: frameworkURL.path)
        
        try processNestedBinaries(at: frameworkURL, outputDir: workingDir)
        
        try processBinary(at: frameworkURL, outputDir: workingDir)
                        
        // Make sure output directory exists
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        
        // Moving xcframeworks to output directory
        
        log("Moving result to output directory")
        
        let xcframeworkURLs = try FileManager.default.contentsOfDirectory(at: workingDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants]).filter { $0.pathExtension == "xcframework" }

        for xcframeworkURL in xcframeworkURLs {
            try FileManager.default.moveItem(at: xcframeworkURL, to: outputURL.appendingPathComponent(xcframeworkURL.lastPathComponent))
        }
        
        // clean up
        try FileManager.default.removeItem(at: workingDir)
    }
    
    /// Processes the Mach-O fat binary located inside the framework
    /// - Parameter frameworkURL: A url pointing to the framework that should be processed
    /// - Parameter outputDir: A url pointing to the output directory where the processed framework should be moved
    ///
    /// The Mach-O fat binary is sliced into smaller binaries containing platform specific architectures
    private func processBinary(at frameworkURL: URL, outputDir: URL) throws {
        // the file name of the framework bundle
        let frameworkName = frameworkURL.deletingPathExtension().lastPathComponent
        
        let frameworkOutputURL = outputDir.appendingPathComponent(frameworkName).appendingPathExtension("xcframework")

        let lipo = Lipo(frameworkURL: frameworkURL)
        
        let architectures = try lipo.availableArchitectures()
        
        let architecturesByPlatform = Dictionary(grouping: architectures, by: { $0.platform })
        var frameworkOutputURLs = [URL]()
        
        for platform in architecturesByPlatform{
            log("Processing binary of framework")
            // create folder with name of the platform that will contain the converted framework
            var frameworkCopyURL = outputDir.appendingPathComponent(platform.key.rawValue)
            try FileManager.default.createDirectory(at: frameworkCopyURL, withIntermediateDirectories: true, attributes: nil)
            frameworkCopyURL = frameworkCopyURL
                .appendingPathComponent(frameworkName)
                .appendingPathExtension("framework")
            frameworkOutputURLs.append(frameworkCopyURL)
            
            // make copy of original input framework and place it in the architecture folder
            try FileManager.default.copyItem(at: frameworkURL, to: frameworkCopyURL)
            // remove the fat Mach-O binary from the framework copy
            try FileManager.default.removeItem(at: frameworkCopyURL.appendingPathComponent(frameworkName))
            
            log("Extracting platform \(platform.key.rawValue) from framework")
            // extract all platform architectures from original framework
            try lipo.extractArchitectures(platform.value, to: frameworkCopyURL.appendingPathComponent(frameworkName).path)
        }
        
        try Xcodebuild.createXCFramework(from: frameworkOutputURLs, outputURL: frameworkOutputURL)
    }
    
    /// Processes the frameworks located in the Frameworks folder of the given `frameworkURL`
    ///
    /// - Parameter frameworkURL: The url pointing to the framework that should be processed
    /// - Parameter outputDir: A url pointing to a directory where the processed frameworks should be moved
    /// The folder is not processed if there is none or if the `ignoreNestedFrameworks` flag is set
    private func processNestedBinaries(at frameworkURL: URL, outputDir: URL) throws {
        // the frameworks folder inside the framework
        let nestedFrameworksURL = frameworkURL.appendingPathComponent("Frameworks")
        guard FileManager.default.fileExists(atPath: nestedFrameworksURL.path, isDirectory: nil) && !ignoreNestedFrameworks else { return }
        
        log("Processing nested frameworks of \(frameworkURL.lastPathComponent)")
        let frameworks = try FileManager.default.contentsOfDirectory(at: nestedFrameworksURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants]).filter { $0.pathExtension == "framework" }
        
        for frameworkURL in frameworks {
            log("Processing \(frameworkURL.lastPathComponent)")
            try createXCFramework(for: frameworkURL, outputURL: outputDir, isVerbose: false)
        }
        
        try FileManager.default.removeItem(at: nestedFrameworksURL)
    }
}

// MARK: Helpers
extension XCFrameworkBuilder {
    private func log(_ message: String) {
        guard isVerbose else { return }
        print(message)
    }
}
