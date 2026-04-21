import Foundation
import MapKit
import CoreLocation

struct DetectedCourse: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let distance: Double
}

enum CourseDetector {
    
    static func detectNearbyCourses(
        latitude: Double,
        longitude: Double
    ) async -> [DetectedCourse] {
        
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "golf course"
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            let userLocation = CLLocation(latitude: latitude, longitude: longitude)
            
            let courses = response.mapItems.compactMap { item -> DetectedCourse? in
                guard let name = item.name else {
                    return nil
                }
                
                let location = item.location
                
                let distance = location.distance(from: userLocation)
                
                return DetectedCourse(
                    name: name,
                    distance: distance
                )
            }
            
            let uniqueCourses = Dictionary(grouping: courses, by: { $0.name })
                .compactMap { $0.value.sorted(by: { $0.distance < $1.distance }).first }
                .sorted(by: { $0.distance < $1.distance })
            
            return Array(uniqueCourses.prefix(8))
            
        } catch {
            print("Failed to detect nearby courses: \(error.localizedDescription)")
            return []
        }
    }
}
