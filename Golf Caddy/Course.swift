import Foundation

struct Course: Codable {
    let name: String
    let city: String
    let state: String
    let holes: [Hole]
}
