//
//  File.swift
//  
//
//  Created by Oliver Krakora on 17.02.22.
//

import Foundation

struct Bash {
    static func isCommandInstalled(_ cmd: String) -> Bool {
        return Process.executeCommand(name: "command", arguments: ["-v", cmd], pipe: nil).terminationStatus == 0
    }
}
