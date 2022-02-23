//
//  File.swift
//  
//
//  Created by Oliver Krakora on 23.02.22.
//

import Foundation
import ArgumentParser

struct Builder: ParsableCommand {
    static var configuration = CommandConfiguration(commandName: "xcframework-builder",
                                                    subcommands: [XCFrameworkBuilder.self, SwiftPackageManager.self], defaultSubcommand: XCFrameworkBuilder.self)
}
