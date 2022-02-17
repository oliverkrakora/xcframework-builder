//
//  File.swift
//  
//
//  Created by Oliver Krakora on 17.02.22.
//

import Foundation
import ArgumentParser

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        self = URL(fileURLWithPath: argument)
    }
}
