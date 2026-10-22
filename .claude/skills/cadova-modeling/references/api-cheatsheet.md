# Cadova API cheat sheet (1.0.x)

Signatures checked against the Cadova 1.0.1 sources. It is a map of what exists, not full docs: when you
need argument details or behaviour, grep the sources or read the matching DocC article (paths come
from `scripts/cadova-paths.sh`).

## Contents
- Output: Model, Project
- 2D primitives
- 3D primitives
- Booleans and builders
- Transforms and placement
- 2D → 3D and back
- Edges and finishing
- Repetition and duplication
- Cutting and splitting
- Measuring
- Printing helpers and environment
- Parts, colors, debugging
- Vectors and angles
- Which DocC article to read

## Output: Model, Project

```swift
await Model("name") { ... }                       // writes Models/name.3mf at the package root
await Model("name", options: .format3D(.stl)) { ... }
await Project {
    Metadata(title: "...", author: "...")
    Environment { $0.tolerance = 0.2 }
    await Model("a") { ... }
    await Group("Plates") { await Model("b") { ... } }
}
```
Models inside a `Project` evaluate in parallel and share environment and metadata.

## 2D primitives

| Type | Initializers |
|---|---|
| `Rectangle` | `(x:y:)`, `(_ size: Vector2D)`, `(_ side:)` — corner at origin, extends +X +Y |
| `Circle` | `(diameter:)`, `(radius:)` — centered |
| `Stadium` | `(x:y:)`, `(_ size:)` |
| `RegularPolygon` | `(sideCount:widthAcrossFlats:)`, `(sideCount:circumradius:)`, `(sideCount:apothem:)`, `(sideCount:sideLength:)` |
| `Polygon` | `(_ points: [Vector2D])` — array literals like `[[0, 0], [10, 0], [10, 5]]` work |
| `Text` | `(_ text: String)`, then `.withFont(_:style:size:)`, `.withTextAlignment(horizontal:vertical:)` |
| `Ring` | `(outerDiameter:innerDiameter:)`, `(outerDiameter:thickness:)`, `(innerDiameter:thickness:)`, radius variants |
| `Arc` | `(range: Range<Angle>, diameter:)`, `(range:radius:)` |
| `BezierPath2D { line(x:y:); curve(...) }` | then `.filled()` or `.stroked(width:alignment:style:)` |

## 3D primitives

| Type | Initializers |
|---|---|
| `Box` | `(x:y:z:)`, `(_ size: Vector3D)`, `(_ side:)` — corner at origin |
| `Cylinder` | `(diameter:height:)`, `(radius:height:)`, `(bottomDiameter:topDiameter:height:)` (cones), plus apex-angle and slant-height variants |
| `Sphere` | `(diameter:)`, `(radius:)`; `Sphere.ellipsoid(x:y:z:)` |
| `Tube` | `(outerDiameter:innerDiameter:height:)`, `(outerDiameter:thickness:height:)`, `(innerDiameter:thickness:height:)` |
| `Torus` | `(outerDiameter:tubeDiameter:)`, `(innerDiameter:tubeDiameter:)`, radius variants |

Cylinders and circles are centered on Z/the origin; boxes and rectangles start at the origin. Use
`.aligned(at:)` rather than translating by half sizes.

## Booleans and builders

```swift
base
    .adding { ... }          // union; builder unions everything inside
    .subtracting { ... }     // difference
    .intersecting { ... }
Union { ... }                 // peers with no primary shape
Intersection { ... }
```
Builders accept `if`, `for`, and local `let`/`@Environment` declarations. A false `if` contributes
nothing; never write `else { Empty() }`. Annotate helper properties with `@GeometryBuilder3D` /
`@GeometryBuilder2D` instead of `return Union { ... }`.

## Transforms and placement

```swift
.translated(x:y:z:)  .translated(Vector3D)
.rotated(x:y:z:)                       // Euler, applied X then Y then Z
.rotated(z: 35°, around: .center)      // pivot on own bounding box
.rotated(angle: 30°, axis: .y)
.rotated(from: .up, to: .forward)
.rotated(90°, around: Line3D(point:direction:))
.scaled(2) .scaled(x:y:z:) .resized(x:y:z:alignment:)
.flipped(along: .x)                    // mirror; there is no `mirrored`
.sheared(.x, along: .z, angle: 25°)
.aligned(at: .centerXY, .bottom)       // .minX .centerX .maxX .left .right .front .back .top .bottom .center .centerXY
.whileAligned(at: ...) { $0... }       // operate in an aligned frame, put back
.whileTransformed(.rotation(z: 30°)) { $0... }
.whileRotated(...)
Stack(.z, spacing: 2, alignment: .centerXY) { ... }
```
Order matters: shape a part around the origin, then place it last with a single `translated`.

## 2D → 3D and back

```swift
profile.extruded(height: h)
profile.extruded(height: h, twist: 120°, topScale: [0.5, 0.5])
profile.extruded(height: h, topEdge: .fillet(radius: 2), bottomEdge: .chamfer(depth: 0.4))
profile.revolved()                     // profile in +X half-plane, Y becomes Z
profile.revolved(in: 0°..<270°)
profile.swept(along: path)             // see CurvesAndPaths.md, also Loft
solid.projected()  solid.projected(onto: .yz)
solid.sliced(atZ: 0)  solid.sliced(along: plane)
```
2D-only refinements before extruding: `.rounded(radius:)`, `.rounded(insideRadius:outsideRadius:)`,
`.offset(amount:style:)` (and its two-closure `{ original, offset in }` form), `.cuttingEdgeProfile(_:on: Rectangle.Corners)`.

## Edges and finishing

```swift
EdgeProfile: .fillet(radius:) .chamfer(depth:) .chamfer(depth:height:) .chamfer(depth:angle:) .overhangFillet(radius:)
solid.cuttingEdgeProfile(.fillet(radius: 2), on: .top)        // any 3D geometry: the outline where it meets a bounding-box side (.top .bottom .left .right .front .back), optional offset:
solid.cuttingEdgeProfile(.chamfer(depth: 1), on: .bottom, offset: 2) { crossSection2D }   // custom cross-section to follow
geometry.cuttingEdgeProfile(.fillet(radius: 2), on: Box.Edge.topFront)   // Box.Edge: .topFront .bottomLeft .verticalBackRight ...; Box.Edges is a Set of them
rectangle2D.cuttingEdgeProfile(.chamfer(depth: 1), on: .all)   // 2D, Rectangle.Corners
solid.shapingEdges(.fillet(radius: 3), matching: <EdgeQuery>)   // edge-finding on arbitrary solids, e.g. matching: .within { maskBox }
solid.hollowed(wallThickness: 2, style: .round)
solid.smoothed(strength:)  solid.refined(maxEdgeLength:)
```
Prefer the extrusion edge parameters when the edge comes from an extrusion; they are cheaper than
edge finding.

## Repetition and duplication

```swift
.repeated(along: .x, spacing: 8, count: 5)    // gap between copies
.repeated(along: .x, step: 8, count: 5)       // pitch between origins
.repeated(along: .x, in: 0..<100, step: 10)
.repeated(around: .z, count: 8)
.repeated(around: .z, in: 0°..<180°, count: 4)
.repeated(along: path, count: 18)
.symmetry(over: .x)  .symmetry(over: [.x, .y])  // original plus mirror(s)
.cloned { $0.rotated(z: 90°) }
.clonedAt(x: 20)                               // slot idiom: Circle(...).clonedAt(x: len).convexHull()
.distributed(at: [0, 8, 20], along: .x)
.distributed(at: transforms)
.convexHull()
```

## Cutting and splitting

```swift
.trimmed(along: .z(0))                         // keeps the positive side; use Plane.z(0).flipped for the other
.within(z: 14...26) { region in ... }          // modify a region, result not re-clipped
.whileMasked(...) { whole in ... }             // result intersected back into the mask
.split(along: .z(24)) { over, under in ... }
.separating(along: plane, into: part)          // detached side becomes its own 3MF part
```

## Measuring

```swift
geometry.measuringBounds { geometry, bounds in ... }   // bounds.size, bounds.minimum, bounds.center ...
geometry.measuring { geometry, measurements in ... }    // area/volume etc.; optional scope first arg
```
Use this when later geometry depends on an earlier shape's size instead of recomputing the size by hand.

## Printing helpers and environment

```swift
@Environment(\.tolerance) var tolerance        // read inside body/builders
.withTolerance(0.2)
Cylinder(diameter: 5, height: 20).overhangSafe()   // call on the Cylinder/Circle itself, before rotating
.overhangSafe(.teardrop) / .overhangSafe(.bridge)
.withOverhangAngle(50°)  .withCircularOverhangMethod(.bridge)
.definingNaturalUpDirection(.up)
.withSegmentation(minAngle: 2°, minSize: 0.15)  .withSegmentation(count: 64)
```
Custom environment keys: `extension EnvironmentValues { private static let key = Key("Project.Name"); var name: T { get { self[Self.key] as! T } set { self[Self.key] = newValue } } }`.

## Parts, colors, debugging

```swift
.colored(.red)  .colored(hex: "#ff8800")  .colored(red:green:blue:alpha:)
.withMaterial(color:metallicness:roughness:name:)
.inPart(name: "Lid")  .inPart(part)
.highlighted()                                 // shows even subtracted geometry, translucent red
.only()                                        // render just this subtree while debugging
```
Remove `.highlighted()` and `.only()` before calling a model done.

## Vectors and angles

- Distances are millimeters, `Double`. `Vector2D` / `Vector3D` accept array literals `[x, y, z]`.
- Angles are `Angle`: write `45°`, combine with `+ - * /`, pass straight to `sin`/`cos`.
  `.degrees(90)` also works; avoid raw radians.
- `Direction3D`: `.up`, `.forward`, `.positiveX` ... ; `Plane`: `.z(10)`, `.x(0)`; `Line3D(point:direction:)`.

## Which DocC article to read

| Need | Article in `Cadova.docc/` |
|---|---|
| Placing by bounding box, Stack | AlignmentAndStacking.md |
| Referencing positions across types | AnchorsAndTags.md |
| Twist, wrap, bend, drape | BendingAndDeforming.md |
| Bezier paths, sweeps, lofts | CurvesAndPaths.md |
| Trim, split, within, masks, parts | CuttingAndSplitting.md |
| Overhangs, tolerance, shells | DesigningFor3DPrinting.md |
| Environment values and custom keys | EnvironmentConcepts.md |
| Full worked models (chamfer, text, loft, table) | Examples.md |
| Extrude, revolve, project, slice | ExtrusionAndRevolution.md |
| Measuring size/area/volume | MeasuringGeometry.md |
| Model/Project/options/export | ModelAndProject.md |
| Rows, grids, rings, mirroring | RepetitionAndPatterns.md |
| Surfaces from points/curves | Surfaces.md |
| Transforms as values, pivots, order | Transformations.md |
| Vectors, Angle | VectorsAndAngles.md |
| Named parts / slicer settings | WorkingWithParts.md |
| Performance, invisible geometry | Troubleshooting.md |
