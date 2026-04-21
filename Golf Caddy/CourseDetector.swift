import Foundation
import MapKit
import CoreLocation

enum CourseDetector {
    static func detectNearbyCourseName(
        latitude: Double,
        longitude: Double
    ) async -> String? {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "golf course"
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            let userLocation = CLLocation(latitude: latitude, longitude: longitude)
            
            let nearest = response.mapItems.min { a, b in
                let aLocation = a.placemark.location ?? CLLocation(latitude: 0, longitude: 0)
                let bLocation = b.placemark.location ?? CLLocation(latitude: 0, longitude: 0)
                return aLocation.distance(from: userLocation) < bLocation.distance(from: userLocation)
            }
            
            return nearest?.name
        } catch {
            print("Failed to detect nearby course: \(error.localizedDescription)")
            return nil
        }
    }
}
