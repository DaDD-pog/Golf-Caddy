// Hello
import SwiftUI
import CoreLocation
import MapKit

struct ContentView: View {
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var peerManager = PeerConnectionManager()
    
    @State private var currentHoleIndex = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasCenteredOnUser = false
    
    @State private var customPin: CLLocationCoordinate2D?
    @State private var customPinDistance: Int = 0
    
    @State private var course: Course?
    @State private var scores: [Int] = []
    @State private var showScorecard = false
    @State private var isLoadingCourse = false
    @State private var detectedCourseName: String?
    
    @State private var rangefinderModeEnabled = true
    
    private var holes: [Hole] {
        course?.holes ?? []
    }
    
    private var currentHole: Hole? {
        guard currentHoleIndex >= 0 && currentHoleIndex < holes.count else { return nil }
        return holes[currentHoleIndex]
    }
    
    private var userCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: locationManager.latitude,
            longitude: locationManager.longitude
        )
    }
    
    private var userLocation: CLLocation {
        CLLocation(
            latitude: locationManager.latitude,
            longitude: locationManager.longitude
        )
    }
    
    private var frontCoordinate: CLLocationCoordinate2D? {
        guard let currentHole else { return nil }
        return CLLocationCoordinate2D(
            latitude: currentHole.frontLatitude,
            longitude: currentHole.frontLongitude
        )
    }
    
    private var centerCoordinate: CLLocationCoordinate2D? {
        guard let currentHole else { return nil }
        return CLLocationCoordinate2D(
            latitude: currentHole.centerLatitude,
            longitude: currentHole.centerLongitude
        )
    }
    
    private var backCoordinate: CLLocationCoordinate2D? {
        guard let currentHole else { return nil }
        return CLLocationCoordinate2D(
            latitude: currentHole.backLatitude,
            longitude: currentHole.backLongitude
        )
    }
    
    private var hasHoleCoordinates: Bool {
        guard let currentHole else { return false }
        
        let coordinates = [
            currentHole.frontLatitude, currentHole.frontLongitude,
            currentHole.centerLatitude, currentHole.centerLongitude,
            currentHole.backLatitude, currentHole.backLongitude
        ]
        
        return coordinates.contains { $0 != 0 }
    }
    
    private var frontYards: Int {
        guard let currentHole, currentHole.frontLatitude != 0, currentHole.frontLongitude != 0 else { return 0 }
        return Int(
            userLocation.distance(
                from: CLLocation(
                    latitude: currentHole.frontLatitude,
                    longitude: currentHole.frontLongitude
                )
            ) * 1.09361
        )
    }
    
    private var centerYards: Int {
        guard let currentHole, currentHole.centerLatitude != 0, currentHole.centerLongitude != 0 else { return 0 }
        return Int(
            userLocation.distance(
                from: CLLocation(
                    latitude: currentHole.centerLatitude,
                    longitude: currentHole.centerLongitude
                )
            ) * 1.09361
        )
    }
    
    private var backYards: Int {
        guard let currentHole, currentHole.backLatitude != 0, currentHole.backLongitude != 0 else { return 0 }
        return Int(
            userLocation.distance(
                from: CLLocation(
                    latitude: currentHole.backLatitude,
                    longitude: currentHole.backLongitude
                )
            ) * 1.09361
        )
    }
    
    private var routeLine: [CLLocationCoordinate2D] {
        guard let centerCoordinate,
              centerCoordinate.latitude != 0,
              centerCoordinate.longitude != 0 else { return [] }
        return [userCoordinate, centerCoordinate]
    }
    
    private var currentScore: Int {
        guard currentHoleIndex >= 0 && currentHoleIndex < scores.count else { return 0 }
        return scores[currentHoleIndex]
    }
    
    private var totalScore: Int {
        scores.reduce(0, +)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    connectionSection
                    courseHeaderSection
                    
                    if isLoadingCourse {
                        ProgressView("Loading course...")
                    }
                    
                    if let detectedCourseName {
                        Text("Detected: \(detectedCourseName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let currentHole {
                        holeHeaderSection(currentHole: currentHole)
                        rangefinderModeSection
                        
                        if locationReady {
                            mapSection(mapHeight: geometry.size.height * 0.45)
                            
                            if hasHoleCoordinates {
                                yardageSection
                            } else {
                                noHoleGPSSection
                            }
                            
                            pinSection
                        } else {
                            Text("Getting location...")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        
                        currentHoleScoreSection(currentHole: currentHole)
                        holeButtons
                        scorecardButton
                    } else {
                        Text("No course data loaded yet.")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showScorecard) {
            ScorecardView(holes: holes, scores: $scores)
        }
        .onAppear {
            peerManager.startHosting()
        }
        .onDisappear {
            peerManager.stopHosting()
        }
        .onChange(of: locationManager.latitude) {
            if !hasCenteredOnUser && locationReady {
                centerOnUser()
                hasCenteredOnUser = true
                autoDetectAndLoadCourse()
            }
            updateCustomPinDistance()
            sendLiveData()
        }
        .onChange(of: locationManager.longitude) {
            updateCustomPinDistance()
            sendLiveData()
        }
        .onChange(of: currentHoleIndex) {
            sendLiveData()
        }
        .onChange(of: scores) {
            sendLiveData()
        }
        .onChange(of: customPinDistance) {
            sendLiveData()
        }
        .onChange(of: peerManager.connectionStatus) {
            if peerManager.connectionStatus == "Connected" {
                sendLiveData()
            }
        }
        .onChange(of: peerManager.receivedScoreUpdate?.id) {
            applyIncomingScoreUpdate()
        }
        .onChange(of: peerManager.receivedHoleChange?.id) {
            applyIncomingHoleChange()
        }
    }
    
    private var locationReady: Bool {
        locationManager.latitude != 0 || locationManager.longitude != 0
    }
    
    private var connectionSection: some View {
        VStack(spacing: 8) {
            Text("iPhone Companion")
                .font(.headline)
            
            Text("Status: \(peerManager.connectionStatus)")
                .foregroundColor(peerManager.connectionStatus == "Connected" ? .green : .secondary)
            
            Text("Peer: \(peerManager.connectedPeerName)")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }
    
    private var courseHeaderSection: some View {
        VStack(spacing: 8) {
            Text(course?.name ?? "Unknown Course")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("\(course?.city ?? ""), \(course?.state ?? "")")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    private func holeHeaderSection(currentHole: Hole) -> some View {
        VStack(spacing: 8) {
            Text("Hole \(currentHole.number)")
                .font(.system(size: 42, weight: .bold))
            
            Text("Par \(currentHole.par)")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
    
    private var rangefinderModeSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rangefinder Mode")
                        .font(.headline)
                    
                    Text(rangefinderModeEnabled ? "Tap anywhere on the map to measure distance." : "Manual measurement is turned off.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $rangefinderModeEnabled)
                    .labelsHidden()
            }
            
            if rangefinderModeEnabled && customPin == nil {
                Text("Tap anywhere on the map to drop a target and measure the distance from your current location.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }
    
    private func mapSection(mapHeight: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    
                    if hasHoleCoordinates,
                       let frontCoordinate,
                       frontCoordinate.latitude != 0,
                       frontCoordinate.longitude != 0 {
                        Annotation("Front", coordinate: frontCoordinate) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    
                    if hasHoleCoordinates,
                       let centerCoordinate,
                       centerCoordinate.latitude != 0,
                       centerCoordinate.longitude != 0 {
                        Annotation("Center", coordinate: centerCoordinate) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                    }
                    
                    if hasHoleCoordinates,
                       let backCoordinate,
                       backCoordinate.latitude != 0,
                       backCoordinate.longitude != 0 {
                        Annotation("Back", coordinate: backCoordinate) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    
                    if hasHoleCoordinates && !routeLine.isEmpty {
                        MapPolyline(coordinates: routeLine)
                            .stroke(.orange, lineWidth: 4)
                    }
                    
                    if let pin = customPin {
                        Annotation("Target", coordinate: pin) {
                            VStack(spacing: 4) {
                                Image(systemName: "scope")
                                    .foregroundColor(.purple)
                                    .font(.title2)
                                
                                Text("\(customPinDistance) yd")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        MapPolyline(coordinates: [userCoordinate, pin])
                            .stroke(.purple, lineWidth: 3)
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .frame(height: mapHeight)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .center) {
                    if rangefinderModeEnabled && customPin == nil {
                        Image(systemName: "plus")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
                .onTapGesture(coordinateSpace: .local) { position in
                    guard rangefinderModeEnabled else { return }
                    
                    if let coordinate = proxy.convert(position, from: .local) {
                        customPin = coordinate
                        updateCustomPinDistance()
                        sendLiveData()
                    }
                }
            }
            
            VStack(spacing: 12) {
                Button {
                    centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                
                if customPin != nil {
                    Button {
                        clearPin()
                        sendLiveData()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.red)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
            }
            .padding(12)
        }
    }
    
    private var yardageSection: some View {
        VStack(spacing: 16) {
            yardageRow(title: "Front", yards: frontYards)
            yardageRow(title: "Center", yards: centerYards)
            yardageRow(title: "Back", yards: backYards)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
    
    private var noHoleGPSSection: some View {
        VStack(spacing: 10) {
            Text("No hole GPS data for this course yet")
                .font(.headline)
            
            Text("Use Rangefinder Mode to tap any point on the map and measure the distance from your current location.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(16)
    }
    
    private var pinSection: some View {
        Group {
            if let pin = customPin {
                VStack(spacing: 14) {
                    Text("Target Distance")
                        .font(.headline)
                    
                    Text("\(customPinDistance) yd")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text("Lat: \(String(format: "%.5f", pin.latitude))   Lon: \(String(format: "%.5f", pin.longitude))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        Button("Move Target") {
                            clearPin()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Target") {
                            clearPin()
                            sendLiveData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.10))
                .cornerRadius(16)
            }
        }
    }
    
    private func currentHoleScoreSection(currentHole: Hole) -> some View {
        VStack(spacing: 12) {
            Text("Score for Hole \(currentHole.number)")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button {
                    scores[currentHoleIndex] -= 1
                    sendLiveData()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                }
                
                Text("\(currentScore)")
                    .font(.system(size: 34, weight: .bold))
                    .frame(minWidth: 50)
                
                Button {
                    scores[currentHoleIndex] += 1
                    sendLiveData()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                }
            }
            
            Text("Total Score: \(totalScore)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }
    
    private var holeButtons: some View {
        HStack(spacing: 20) {
            Button("Previous Hole") {
                if currentHoleIndex > 0 {
                    currentHoleIndex -= 1
                    clearPin()
                    sendLiveData()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Next Hole") {
                if currentHoleIndex < holes.count - 1 {
                    currentHoleIndex += 1
                    clearPin()
                    sendLiveData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var scorecardButton: some View {
        Button("Open Scorecard") {
            showScorecard = true
        }
        .buttonStyle(.borderedProminent)
        .disabled(holes.isEmpty)
    }
    
    private func clearPin() {
        customPin = nil
        customPinDistance = 0
    }
    
    private func centerOnUser() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.002,
                longitudeDelta: 0.002
            )
        )
        
        cameraPosition = .region(region)
    }
    
    private func updateCustomPinDistance() {
        guard let pin = customPin else { return }
        
        let pinLocation = CLLocation(
            latitude: pin.latitude,
            longitude: pin.longitude
        )
        
        customPinDistance = Int(userLocation.distance(from: pinLocation) * 1.09361)
    }
    
    private func autoDetectAndLoadCourse() {
        guard locationReady else { return }
        guard !isLoadingCourse else { return }
        
        isLoadingCourse = true
        
        Task {
            let detectedName = await CourseDetector.detectNearbyCourseName(
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            )
            
            await MainActor.run {
                detectedCourseName = detectedName
            }
            
            guard let detectedName else {
                await MainActor.run {
                    isLoadingCourse = false
                }
                return
            }
            
            do {
                let loadedCourse = try await GolfCourseAPIClient.loadCourse(named: detectedName)
                
                await MainActor.run {
                    if let loadedCourse {
                        course = loadedCourse
                        currentHoleIndex = 0
                        scores = Array(repeating: 0, count: loadedCourse.holes.count)
                        clearPin()
                        sendLiveData()
                    }
                    isLoadingCourse = false
                }
            } catch {
                await MainActor.run {
                    print("API error: \(error.localizedDescription)")
                    isLoadingCourse = false
                }
            }
        }
    }
    
    private func sendLiveData() {
        guard let currentHole else { return }
        
        let data = GolfSyncData(
            holeNumber: currentHole.number,
            totalHoles: holes.count,
            par: currentHole.par,
            frontYards: frontYards,
            centerYards: centerYards,
            backYards: backYards,
            currentScore: currentScore,
            totalScore: totalScore,
            pinDistance: customPin != nil ? customPinDistance : nil
        )
        
        peerManager.sendGolfData(data)
    }
    
    private func applyIncomingScoreUpdate() {
        guard let update = peerManager.receivedScoreUpdate else { return }
        guard update.holeIndex >= 0 && update.holeIndex < scores.count else { return }
        
        scores[update.holeIndex] = update.score
        
        if currentHoleIndex == update.holeIndex {
            sendLiveData()
        } else {
            currentHoleIndex = update.holeIndex
            clearPin()
            sendLiveData()
        }
    }
    
    private func applyIncomingHoleChange() {
        guard let change = peerManager.receivedHoleChange else { return }
        guard change.holeIndex >= 0 && change.holeIndex < holes.count else { return }
        
        currentHoleIndex = change.holeIndex
        clearPin()
        sendLiveData()
    }
    
    private func yardageRow(title: String, yards: Int) -> some View {
        HStack {
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Text("\(yards) yd")
        }
        .font(.title3)
    }
}

#Preview {
    ContentView()
}
