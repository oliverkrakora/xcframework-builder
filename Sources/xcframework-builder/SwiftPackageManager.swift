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
    
    @Option
    private var outputPath: URL
    
    func run() throws {
        var frameworks = [String]()
        
        if frameworkPath.pathExtension.isEmpty {
            frameworks = try FileManager.default.contentsOfDirectory(at: frameworkPath,
                                                                            includingPropertiesForKeys: [.isDirectoryKey],
                                                                     options: [.skipsPackageDescendants]).filter { $0.pathExtension == "xcframework" }
                                                                     .map { $0.path }
        } else {
            frameworks.append(frameworkPath.path)
        }
        
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
        
        let outputPath = outputPath.appendingPathComponent("Package").appendingPathExtension("swift")
        
        FileManager.default.createFile(atPath: outputPath.path, contents: manifestData, attributes: nil)
    }
}
