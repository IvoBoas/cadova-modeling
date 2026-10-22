---
name: cadova-modeling
description: Design, write, modify and debug 3D-printable models in Swift with the Cadova library (tomasf/Cadova) in this CadovaModeling package. Use this whenever the user wants to create a new model, change dimensions or features of an existing one (like the desk organizer), add holes, fillets, chamfers, pockets, text, threads or fits, make a part printable, split a model into parts, or asks how to do something in Cadova — even if they just describe a physical object ("make me a cable clip", "the pen holder is too tight", "add a drawer") without naming Cadova or Swift.
---

# Cadova modeling

This package builds 3D-printable models in Swift with [Cadova](https://github.com/tomasf/Cadova).
Running the executable writes each model to `Models/<name>.3mf`, which the user inspects in Cadova
Viewer (it reloads when the file changes) and then slices.

Cadova is a young, niche library, so your memory of its API is unreliable. Model code that looks
plausible but calls a method that does not exist, or passes `radius:` where only `diameter:` exists,
is the most common failure. The remedy is cheap: the exact version this package uses is checked out
locally, with its docs, style guide and sources. Read them instead of guessing.

## Project facts

- `Package.swift`: one executable target `CadovaModeling` depending on Cadova `from: "1.0.0"`
  (resolved 1.0.1), swift-tools 6.4, macOS 15, C++ interop and `ApproachableConcurrency` enabled.
- `Sources/CadovaModeling/main.swift`: the entry point. Top-level `await Model(...)` / `await Project`
  calls live here.
- `Models/`: generated `.3mf` files, committed to git. Don't edit them by hand.
- The existing `desk_organizer` model sits entirely in `main.swift`, with its dimensions as
  `private extension Double` / `Vector3D` / `[Vector2D]` statics at the bottom of the file.

## Step 1: Locate the Cadova reference material

Run the bundled script from the package root:

```bash
.claude/skills/cadova-modeling/scripts/cadova-paths.sh
```

It prints the resolved version and the paths to the checkout, `CadovaStyleGuide.md`, the DocC
articles (`Cadova.docc/*.md`) and the sources. If it can't find a checkout, packages haven't been
resolved yet; fall back to https://cadova.org/docs and say so.

Then:

1. **Read `CadovaStyleGuide.md` once per session** before writing model code. It is written by the
   library author for exactly this purpose and covers the choices that compile either way but only
   one reads like Cadova (builders vs `Union`, `.aligned` vs half-size translations, tolerance from
   the environment, 2D-then-extrude, etc.).
2. **Skim `references/api-cheatsheet.md`** (in this skill) to see what operations exist and which
   DocC article covers a topic. Read that article when the task touches it.
3. **Verify every API you are not certain of** by grepping the sources, e.g.
   `grep -rn "func overhangSafe" "<sources>"` or `grep -rn "init(" "<sources>/Abstract Layer/3D/Tube.swift"`.
   Doc comments in the sources usually include a usage example. This takes seconds and is the main
   substitute for compiling (see "Verifying" below).

## Step 2: Pin down the physical object

Before writing geometry, make sure you know (ask only for what you can't sensibly default):

- **Dimensions in millimeters**, and which ones are hard constraints (the phone that must fit, the
  pen diameter, the screw size) versus free choices.
- **Fits**: what has to slide, press or clear against what. Those gaps come from `\.tolerance`.
- **Print orientation**: Z is up and Z = 0 is the bed. Design so the part sits flat on Z = 0 in the
  orientation it will print, with overhangs under ~45° or explicitly handled.
- **Printer constraints** worth defaulting unless told otherwise: 0.4 mm nozzle, walls ≥ 1.2 mm,
  floors ≥ 0.8 mm, the part fits a ~220 × 220 mm bed (the desk organizer's 260 mm base already
  exceeds that; mention it if relevant rather than silently changing it).

State the coordinate plan in a sentence or two when the layout isn't obvious: where the origin is,
which way the part faces, what is placed relative to what.

## Step 3: Write the geometry

Follow the style guide. The points that matter most in practice:

- **Model in 2D, then extrude or revolve.** Rounding, offsetting and insetting are easy in 2D and
  hard in 3D. `Rectangle(...).rounded(radius:).extruded(height:topEdge:bottomEdge:)` beats a `Box`
  whose edges you then try to round.
- **One chain from a base shape**, with `.adding {}`, `.subtracting {}`, `.intersecting {}` hanging
  off it and one call per line. Name a `let` only when a shape is reused.
- **Place with alignment, not arithmetic.** `Rectangle`/`Box` start at the origin and extend into +X
  +Y (+Z); `Circle`/`Cylinder`/`Sphere` are centered on the origin. `.aligned(at: .centerXY, .bottom)`
  states intent and survives dimension changes; `translated(x: -w / 2)` doesn't.
- **Shape around the origin, place last.** Rotations pivot on the origin and Euler angles apply X,
  then Y, then Z, so rotate a part while it's still at the origin and finish with one `translated`.
- **Every number has a name**, derived values are computed from the names they depend on, and
  diameters are preferred over radii (Cadova's API is diameter-first).
- **Clearances come from the environment**: `@Environment(\.tolerance) var tolerance` inside the
  body, `.withTolerance(...)` or a project-level `Environment { $0.tolerance = 0.2 }` to set it.
- **Use the built-in operation**: `repeated`, `symmetry`, `clonedAt(...).convexHull()` for slots,
  `overhangSafe()` for horizontal holes, `cuttingEdgeProfile`/`shapingEdges`/extrusion edge profiles
  for fillets and chamfers, `split(along:)` for multi-piece prints, `Stack` for end-to-end layout,
  `measuringBounds` when later geometry depends on an earlier shape's size.
- **Let cutters overshoot.** A subtracted shape that ends exactly flush with a face can leave a
  zero-thickness skin; extend it a little past the surface it cuts through (e.g. height + 1, moved
  down by 0.5) unless it is meant to stop at a floor.

### Where code goes in this package

- **New models**: put the geometry in its own file, `Sources/CadovaModeling/<Name>.swift`, as
  `struct <Name>: Geometry3D` with its dimensions as `static let`s on that type (or `let`s at the top
  of `body` if nothing else needs them). Add a `Model("<file_name>") { <Name>() }` to `main.swift`.
  Once `main.swift` holds more than one model, wrap them in `await Project { ... }` so they build in
  parallel and can share `Environment` and `Metadata`. This is the layout the style guide
  recommends ("keep main.swift a manifest").
- **Editing the desk organizer**: match the code that's there, including its `.constantName`
  extensions on `Double`/`Vector3D`. Don't restructure it into a type unless the user asks; if it's
  about to gain another model alongside it, offer the move instead of doing it unannounced.
- **Comments**: keep them rare. A short `// Feature name` label above a major `.adding`/`.subtracting`
  block in a long chain is fine (the existing file uses `// Base`-style section labels); don't
  narrate what each call does.

## Step 4: Check printability

Run through this before calling the model done:

- The part rests on Z = 0 with a flat face, in its intended print orientation.
- Horizontal round holes use `.overhangSafe()` called on the `Cylinder`/`Circle` itself, before any
  alignment or rotation; it reads the up direction from the environment.
- Bottom edges touching the bed use a chamfer or `.overhangFillet(radius:)`, not a plain fillet;
  top edges can use any fillet.
- Mating features use the environment tolerance, and the user knows which value is in effect.
- No accidental floating islands, zero-thickness walls, or debug modifiers (`.highlighted()`,
  `.only()`) left in the code.

## Verifying

Don't build or run the package to test changes unless the user explicitly asks; they generate and
inspect models themselves. That makes static checking your job:

- Re-read every Cadova call you wrote and confirm each one against the sources or docs if you
  haven't already in this session. Check labels (`diameter:` vs `radius:`, `spacing:` vs `step:`),
  2D vs 3D (`Geometry2D` methods don't exist on `Geometry3D` and vice versa), and that builder
  closures return geometry of the right dimensionality.
- Walk through the coordinates of key features: where does each one end up after its transforms?
  Do cutters actually intersect the solid they're meant to cut? Is anything placed below Z = 0?
- When something might be invisible or misplaced, suggest the user temporarily add `.highlighted()`
  to it (subtracted geometry shows in translucent red) or `.only()` to preview it alone.

If the user does ask you to generate the model, run `swift run` from the package root (in the
background, since a first build can take a while); it writes `Models/<name>.3mf`.

## Reporting back

Tell the user, briefly: what the model or change does, the key dimensions and any you chose
yourself, the tolerance in effect for fits, anything about printability they should know
(orientation, supports, bed size), and what to look at in the viewer to confirm it's right.
