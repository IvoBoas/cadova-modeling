import Cadova

await Model("desk_organizer") {
	let base = Rectangle(x: .baseWidth, y: .baseDepth)
		.rounded(radius: .baseCornerRadius)
		.extruded(height: .baseHeight)
		.shapingEdges(.fillet(radius: .baseTopEdgeFillet), matching: .within {
			Box(x: .baseWidth, y: .baseDepth, z: .baseTopEdgeFillet)
				.translated(z: .baseHeight - .baseTopEdgeFillet)
		})

	let drawerCavity = Box(x: .drawerCavityWidth, y: .drawerCavityDepth, z: .drawerCavityHeight)

	let penHolder = Cylinder(diameter: .penHolderOutterDiameter, height: .penHolderHeight)
		.subtracting {
			Cylinder(diameter: .penHolderInnerDiameter, height: .penHolderHeight - .penHolderBaseThickness)
				.translated(z: .penHolderBaseThickness)
		}

	let storage = Polygon(.storageSide)
		.extruded(height: .storageWidth)
		.rotated(x: .degrees(90), z: .degrees(90))
		.subtracting {
			Box(x: .storagePocketWidth, y: .storagePocketDepth, z: .storagePocketHeight)
				.translated(.storageBackPocketTranslation)

			Box(x: .storagePocketWidth, y: .storagePocketDepth, z: .storagePocketHeight)
				.translated(.storageFrontPocketTranslation)
		}

	let phoneStand = Box(x: .backrestWidth, y: .backrestHeight, z: .backrestThickness)
		.rotated(.degrees(90 - .backrestTilt), around: .x)

	base
		.subtracting { drawerCavity.translated(.drawerCavityTranslation) }
		.adding { penHolder.translated(.penHolderTranslation) }
		.adding { storage.translated(.storageTranslation) }
		.adding { phoneStand.translated(.phoneStandTranslation) }
}

// MARK: - Constants
private extension Double {
	// Base
	static let baseWidth: Self = 260
	static let baseDepth: Self = 130
	static let baseHeight: Self = 32
	static let baseCornerRadius: Self = 12
	static let baseThickness: Self = 5
	static let baseTopEdgeFillet: Self = 3

	// Drawer Cavity
	static let drawerCavityWidth: Self = 200
	static let drawerCavityDepth: Self = 98
	static let drawerCavityHeight: Self = 20

	// Pen Holder
	static let penHolderOutterDiameter: Self = 58
	static let penHolderInnerDiameter: Self = 50
	static let penHolderHeight: Self = 65 + 4
	static let penHolderBaseThickness: Self = 4

	// Storage
	static let storageWidth: Self = 102
	static let storageDepth: Self = 88
	static let storageThickness: Self = 3
	static let storageBackHeight: Self = 38
	static let storageFrontHeight: Self = 25
	static let storagePocketDepth: Double = (.storageDepth - (.storageThickness * 3)) * 0.5
	static let storagePocketWidth: Double = .storageWidth - (.storageThickness * 2)
	static let storagePocketHeight: Double = .storageBackHeight - .storageThickness

	// Phone Stand
	static let backrestWidth: Self = 58
	static let backrestHeight: Self = 93
	static let backrestThickness: Self = 5
	static let backrestTilt: Self = 15
	static let retainingLipHeight: Self = 10
}

private extension Vector3D {
	static let drawerCavityTranslation: Self = {
		let x: Double = (.baseWidth - .drawerCavityWidth) * 0.5
		let z: Double = (.baseHeight - .drawerCavityHeight) * 0.5
		return .init(x: x, y: .zero, z: z)
	}()

	static let penHolderTranslation: Self = {
		let y: Double = .baseDepth - 45
		return .init(x:39, y: y, z: .baseHeight)
	}()

	static let storageTranslation: Self = .init(x: 77, y: 24, z: .baseHeight)

	static let storageFrontPocketTranslation: Self = .init(
		x: .storageThickness,
		y: .storageThickness,
		z: .storageThickness
	)

	static let storageBackPocketTranslation: Self = .init(
		x: .storageThickness,
		y: (.storageThickness * 2) + .storagePocketDepth,
		z: .storageThickness
	)

	static let phoneStandTranslation: Self = .init(
		x: 185,
		y: .baseDepth * 0.5,
		z: .baseHeight
	)
}

private extension Array where Element == Vector2D {
	static let storageSide: Self = [
		[0, 0],
		[.storageDepth, 0],
		[.storageDepth, .storageBackHeight],
		[0, .storageFrontHeight]
	]
}
