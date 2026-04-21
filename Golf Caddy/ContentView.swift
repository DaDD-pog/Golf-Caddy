import SwiftUI
import CoreLocation
import MapKit

struct ContentView: View {
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var peerManager = PeerConnectionManager()
    
    @State private var currentHoleIndex = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasStartedInitialLoad = false
    
    @State private var customPin: CLLocationCoordinate2D?
    @State private var customPinDistance: Int = 0
    
    @State private var course: Course?
    @State private var scores: [Int] = []
    @State private var showScorecard = false
    
    @State private var isLoadingCourse = false
    @State private var detectedCourseName: String?
    @State private var loadingMessage = "Waiting for location..."
    @State private var loadingErrorMessage: String?
    
    @State private var rangefinderModeEnabled = true
    
    @State private var nearbyCourses: [DetectedCourse] = []
    @State private var showCoursePicker = false
    
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
        guard let currentHole,
              currentHole.frontLatitude != 0,
              currentHole.frontLongitude != 0 else { return 0 }
        
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
        guard let currentHole,
              currentHole.centerLatitude != 0,
              currentHole.centerLongitude != 0 else { return 0 }
        
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
        guard let currentHole,
              currentHole.backLatitude != 0,
              currentHole.backLongitude != 0 else { return 0 }
        
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
    
    private var locationReady: Bool {
        locationManager.latitude != 0 || locationManager.longitude != 0
    }
    
    private var mainLandscapeYardageValue: String {
        if hasHoleCoordinates && centerYards > 0 {
            return "\(centerYards)"
        }
        
        if customPin != nil && customPinDistance > 0 {
            return "\(customPinDistance)"
        }
        
        return "--"
    }
    
    private var mainLandscapeYardageLabel: String {
        if hasHoleCoordinates && centerYards > 0 {
            return "CENTER"
        }
        
        if customPin != nil && customPinDistance > 0 {
            return "TARGET"
        }
        
        return "YARDS"
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            Group {
                if isLandscape, currentHole != nil {
                    landscapeCartView(geometry: geometry)
                } else {
                    portraitView(geometry: geometry)
                }
            }
        }
        .sheet(isPresented: $showScorecard) {
            ScorecardView(holes: holes, scores: $scores)
        }
        .sheet(isPresented: $showCoursePicker) {
            CoursePickerView(
                courses: nearbyCourses,
                onSelect: { selected in
                    showCoursePicker = false
                    loadSelectedCourse(selected.name)
                },
                onManualRound: {
                    showCoursePicker = false
                    startManualRound()
                }
            )
        }
        .onAppear {
            peerManager.startHosting()
        }
        .onDisappear {
            peerManager.stopHosting()
        }
        .onChange(of: locationManager.latitude) {
            handleLocationUpdate()
        }
        .onChange(of: locationManager.longitude) {
            handleLocationUpdate()
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
    
    private func portraitView(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                connectionSection
                courseHeaderSection
                
                if isLoadingCourse {
                    ProgressView(loadingMessage)
                }
                
                if let detectedCourseName {
                    Text("Detected: \(detectedCourseName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let loadingErrorMessage {
                    errorSection(message: loadingErrorMessage)
                }
                
                if let currentHole {
                    holeHeaderSection(currentHole: currentHole)
                    rangefinderModeSection
                    
                    if locationReady {
                        mapSection(mapHeight: geometry.size.height * 0.45, rounded: true)
                        
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
                    emptyCourseSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
    
    private func landscapeCartView(geometry: GeometryProxy) -> some View {
        ZStack {
            if locationReady {
                mapSection(mapHeight: geometry.size.height, rounded: false)
                    .ignoresSafeArea()
            } else {
                Color(.systemGray6)
                    .ignoresSafeArea()
            }
            
            if locationReady {
                VStack {
                    giantLandscapeYardageOverlay
                        .padding(.top, 90)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        connectionCompactSection
                        courseCompactSection
                        holeCompactSection
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 12) {
                        if isLoadingCourse {
                            compactCard {
                                ProgressView(loadingMessage)
                            }
                        }
                        
                        if let loadingErrorMessage {
                            compactCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Error")
                                        .font(.headline)
                                    Text(loadingErrorMessage)
                                        .font(.subheadline)
                                }
                                .foregroundColor(.red)
                            }
                        }
                        
                        if hasHoleCoordinates {
                            largeYardageHud
                        } else {
                            compactCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Map Mode")
                                        .font(.headline)
                                    Text("No hole GPS data. Tap anywhere to measure distance.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        compactCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Rangefinder")
                                    .font(.headline)
                                
                                Toggle("Enable", isOn: $rangefinderModeEnabled)
                                
                                if let pin = customPin {
                                    Text("Target: \(customPinDistance) yd")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                    
                                    Text("Lat: \(String(format: "%.5f", pin.latitude))  Lon: \(String(format: "%.5f", pin.longitude))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Tap on the map to drop a target.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if customPin != nil {
                            Button("Clear Target") {
                                clearPin()
                                sendLiveData()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button {
                            centerOnUser()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        
                        Button("Scorecard") {
                            showScorecard = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Spacer()
                    
                    compactCard {
                        VStack(spacing: 12) {
                            Text("Score")
                                .font(.headline)
                            
                            HStack(spacing: 18) {
                                Button {
                                    guard !scores.isEmpty else { return }
                                    scores[currentHoleIndex] -= 1
                                    sendLiveData()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 34))
                                }
                                
                                Text("\(currentScore)")
                                    .font(.system(size: 34, weight: .bold))
                                    .frame(minWidth: 50)
                                
                                Button {
                                    guard !scores.isEmpty else { return }
                                    scores[currentHoleIndex] += 1
                                    sendLiveData()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 34))
                                }
                            }
                            
                            Text("Total: \(totalScore)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 16) {
                                Button("Previous") {
                                    if currentHoleIndex > 0 {
                                        currentHoleIndex -= 1
                                        clearPin()
                                        sendLiveData()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Next") {
                                    if currentHoleIndex < holes.count - 1 {
                                        currentHoleIndex += 1
                                        clearPin()
                                        sendLiveData()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
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
    
    private var connectionCompactSection: some View {
        compactCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Companion")
                    .font(.headline)
                Text("Status: \(peerManager.connectionStatus)")
                    .foregroundColor(peerManager.connectionStatus == "Connected" ? .green : .secondary)
                Text("Peer: \(peerManager.connectedPeerName)")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
    }
    
    private var courseHeaderSection: some View {
        VStack(spacing: 8) {
            Text(course?.name ?? "No Course Loaded")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("\(course?.city ?? ""), \(course?.state ?? "")")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    private var courseCompactSection: some View {
        compactCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(course?.name ?? "No Course Loaded")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(course?.city ?? ""), \(course?.state ?? "")")
                    .foregroundColor(.secondary)
                
                if let detectedCourseName {
                    Text("Detected: \(detectedCourseName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
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
    
    private var holeCompactSection: some View {
        compactCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hole \(currentHole?.number ?? 0)")
                    .font(.system(size: 30, weight: .bold))
                Text("Par \(currentHole?.par ?? 0)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var rangefinderModeSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rangefinder Mode")
                        .font(.headline)
                    
                    Text(
                        rangefinderModeEnabled
                        ? "Tap anywhere on the map to measure distance."
                        : "Manual measurement is turned off."
                    )
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
    
    private func mapSection(mapHeight: CGFloat, rounded: Bool) -> some View {
        let mapView =
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
        
        return Group {
            if rounded {
                mapView
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                mapView
            }
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
    
    private var largeYardageHud: some View {
        compactCard {
            VStack(alignment: .trailing, spacing: 10) {
                Text("Yardages")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    VStack(alignment: .trailing) {
                        Text("Front")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(frontYards)")
                            .font(.system(size: 34, weight: .bold))
                    }
                    
                    VStack(alignment: .trailing) {
                        Text("Center")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(centerYards)")
                            .font(.system(size: 42, weight: .bold))
                    }
                    
                    VStack(alignment: .trailing) {
                        Text("Back")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(backYards)")
                            .font(.system(size: 34, weight: .bold))
                    }
                }
            }
        }
    }
    
    private var giantLandscapeYardageOverlay: some View {
        VStack(spacing: 4) {
            Text(mainLandscapeYardageLabel)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.9))
            
            Text(mainLandscapeYardageValue)
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text("yd")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 8)
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
                    guard !scores.isEmpty else { return }
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
                    guard !scores.isEmpty else { return }
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
    
    private func errorSection(message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.headline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Retry") {
                    retryCourseLoad()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Load Demo Course") {
                    loadDemoCourse()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.08))
        .cornerRadius(16)
    }
    
    private var emptyCourseSection: some View {
        VStack(spacing: 12) {
            Text("No course data loaded yet.")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("The app needs your location to detect a course, or you can load the demo course.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("Retry") {
                    retryCourseLoad()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Load Demo Course") {
                    loadDemoCourse()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    private func compactCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 3)
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
    
    private func handleLocationUpdate() {
        updateCustomPinDistance()
        sendLiveData()
        
        guard locationReady else { return }
        
        if !hasStartedInitialLoad {
            hasStartedInitialLoad = true
            centerOnUser()
            retryCourseLoad()
        }
    }
    
    private func retryCourseLoad() {
        guard locationReady else {
            loadingErrorMessage = "Location is not ready yet. Check location permissions and wait a moment."
            return
        }
        
        autoDetectAndLoadCourse()
    }
    
    private func loadDemoCourse() {
        if let demoCourse = CourseLoader.loadCourse(named: "demo_course") {
            course = demoCourse
            currentHoleIndex = 0
            scores = Array(repeating: 0, count: demoCourse.holes.count)
            loadingErrorMessage = nil
            detectedCourseName = demoCourse.name
            clearPin()
            centerOnUser()
            sendLiveData()
        } else {
            loadingErrorMessage = "Could not load the bundled demo course."
        }
    }
    
    private func autoDetectAndLoadCourse() {
        guard locationReady else { return }
        guard !isLoadingCourse else { return }
        
        isLoadingCourse = true
        loadingErrorMessage = nil
        loadingMessage = "Detecting nearby course..."
        
        Task {
            let detectedCourses = await CourseDetector.detectNearbyCourses(
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            )
            
            await MainActor.run {
                nearbyCourses = detectedCourses
                isLoadingCourse = false
                
                if detectedCourses.isEmpty {
                    loadingErrorMessage = "Could not detect any nearby golf courses."
                } else {
                    showCoursePicker = true
                }
            }
        }
    }
    
    private func loadSelectedCourse(_ name: String) {
        isLoadingCourse = true
        loadingMessage = "Loading \(name)..."
        loadingErrorMessage = nil
        
        Task {
            do {
                let loadedCourse = try await GolfCourseAPIClient.loadCourse(named: name)
                
                await MainActor.run {
                    if let loadedCourse {
                        course = loadedCourse
                        currentHoleIndex = 0
                        scores = Array(repeating: 0, count: loadedCourse.holes.count)
                        detectedCourseName = name
                        clearPin()
                        centerOnUser()
                        sendLiveData()
                        loadingErrorMessage = nil
                    } else {
                        loadingErrorMessage = "Could not load selected course."
                    }
                    
                    isLoadingCourse = false
                }
            } catch {
                await MainActor.run {
                    loadingErrorMessage = error.localizedDescription
                    isLoadingCourse = false
                }
            }
        }
    }
    
    private func startManualRound() {
        let manualCourse = createManualCourse()
        course = manualCourse
        currentHoleIndex = 0
        scores = Array(repeating: 0, count: manualCourse.holes.count)
        detectedCourseName = "Manual Round"
        loadingErrorMessage = nil
        clearPin()
        centerOnUser()
        sendLiveData()
    }
    
    private func createManualCourse() -> Course {
        let holes = (1...18).map { holeNumber in
            Hole(
                number: holeNumber,
                par: 4,
                frontLatitude: 0,
                frontLongitude: 0,
                centerLatitude: 0,
                centerLongitude: 0,
                backLatitude: 0,
                backLongitude: 0
            )
        }
        
        return Course(
            name: "Manual Round",
            city: "",
            state: "",
            holes: holes
        )
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
