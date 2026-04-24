import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationErrorMessage: String?
    
    var isLocationReady: Bool {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return false
        }
        
        guard let currentLocation else {
            return false
        }
        
        let accuracy = currentLocation.horizontalAccuracy
        
        guard accuracy >= 0 else {
            return false
        }
        
        return accuracy <= 50
    }
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = manager.authorizationStatus
        
        if CLLocationManager.locationServicesEnabled() {
            if authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        } else {
            locationErrorMessage = "Location Services are turned off on this device."
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationErrorMessage = nil
            manager.startUpdatingLocation()
            
        case .denied:
            locationErrorMessage = "Location access was denied. Turn it on in Settings."
            
        case .restricted:
            locationErrorMessage = "Location access is restricted on this device."
            
        case .notDetermined:
            locationErrorMessage = "Waiting for location permission."
            
        @unknown default:
            locationErrorMessage = "Unknown location authorization state."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        
        if location.horizontalAccuracy >= 0 {
            locationErrorMessage = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationErrorMessage = error.localizedDescription
    }
}
