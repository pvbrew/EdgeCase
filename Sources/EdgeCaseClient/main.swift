import EdgeCase

@EdgeCases
struct Coordinate {
    let x: Int
    let y: Int
}

print("Coordinate.edgeCases: \(Coordinate.edgeCases)")
