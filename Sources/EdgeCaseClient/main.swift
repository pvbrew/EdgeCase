import EdgeCase

@EdgeCases
struct User {
    let id: Int
    let name: String
    var isActive: Bool
    let karma: Double
}

print("User.edgeCases generated \(User.edgeCases.count) instances:")
for user in User.edgeCases {
    print("  \(String(describing: user).prefix(96))")
}
