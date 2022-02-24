//
//  StencilTemplates.swift
//  
//
//  Created by Oliver Krakora on 23.02.22.
//

import Foundation

enum StencilTemplates {
    static let spm: String = """
    // swift-tools-version:{{ swiftVersion }}
    // The swift-tools-version declares the minimum version of Swift required to build this package.

    import PackageDescription

    let package = Package(
        name: "{{ frameworkName }}",
        products: [
            .library(
                name: "{{ frameworkName }}",
                targets: [
                    {% for framework in frameworks %}
                    "{{ framework }}",
                    {% endfor %}
                ])
        ],
        targets: [
            {% for framework in frameworks %}
            .binaryTarget(name: "{{ framework }}", path: "{{ framework }}.xcframework"),
            {% endfor %}
        ]
    )
    """
}
