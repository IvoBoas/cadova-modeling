// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "CadovaModeling",
	platforms: [.macOS(.v15)],
	dependencies: [.package(url: "https://github.com/tomasf/Cadova.git", from: "1.0.0")],
	targets: [
		.executableTarget(
			name: "CadovaModeling",
			dependencies: ["Cadova"],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
				.interoperabilityMode(.Cxx)
			],
		),
		.testTarget(
			name: "CadovaModelingTests",
			dependencies: ["CadovaModeling"],
			swiftSettings: [
				.enableUpcomingFeature("ApproachableConcurrency"),
			],
		),
	]
)
