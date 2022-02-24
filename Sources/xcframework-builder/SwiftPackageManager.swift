//
//  File.swift
//  
//
//  Created by Oliver Krakora on 23.02.22.
//

import Foundation
import ArgumentParser
import Stencil

struct SwiftPackageManager: ParsableCommand {
    
    enum Error: Swift.Error {
        case unknown
    }
    
    static var _commandName: String {
        return "spm"
    }
    
    @Option
    private var swiftVersion: String = "5.5"
    
    @Option
    private var frameworkName: String
    
    @Option
    private var frameworkPath: URL
    
    func run() throws {
        var frameworks = [String]()
        var outputPath: URL?
        
        if frameworkPath.pathExtension.isEmpty {
            let urls  = try FileManager.default.contentsOfDirectory(at: frameworkPath,
                                                                            includingPropertiesForKeys: [.isDirectoryKey],
                                                                     options: [.skipsPackageDescendants]).filter { $0.pathExtension == "xcframework" }
                                                                     
            outputPath = urls.first?.deletingLastPathComponent()
            frameworks = urls.map { $0.deletingPathExtension().lastPathComponent }
        } else {
            outputPath = frameworkPath
            frameworks.append(frameworkPath.path)
        }
        
        guard var outputPath = outputPath else { return }
        
        let dictionaryLoader = DictionaryLoader(templates: ["spm": StencilTemplates.spm])
        let environment = Environment(loader: dictionaryLoader, extensions: [])
        
        var context = [String: Any]()
        context["frameworks"] = frameworks
        context["frameworkName"] = frameworkName
        context["swiftVersion"] = swiftVersion
        
        guard let manifestData = try environment.renderTemplate(name: "spm", context: context).data(using: .utf8) else {
            throw Error.unknown
        }
        
        try FileManager.default.createDirectory(at: outputPath, withIntermediateDirectories: true, attributes: nil)
        
        outputPath = outputPath
            .appendingPathComponent("Package")
            .appendingPathExtension("swift")
        
        FileManager.default.createFile(atPath: outputPath.path, contents: manifestData, attributes: nil)
    }
}
