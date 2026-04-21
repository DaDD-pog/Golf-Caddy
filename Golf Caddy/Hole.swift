import Foundation

struct Hole: Identifiable, Codable {
    var id: Int { number }
    
    let number: Int
    let par: Int
    
    let frontLatitude: Double
    let frontLongitude: Double
    
    let centerLatitude: Double
    let centerLongitude: Double
    
    let backLatitude: Double
    let backLongitude: Double
}
