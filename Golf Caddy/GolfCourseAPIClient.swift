import Foundation

// 🔥 Wrapper for API response
struct CourseDetailWrapper: Codable {
    let course: CourseDetailResponse
}

// MARK: - Search Models

struct CourseSearchResponse: Codable {
    let courses: [CourseSearchItem]?
}

struct CourseSearchItem: Codable {
    let id: Int?
    let club_name: String?
    let course_name: String?
}

// MARK: - Detail Models

struct CourseDetailResponse: Codable {
    let id: Int?
    let club_name: String?
    let course_name: String?
    let location: APILocation?
    let tees: APITees?
}

struct APILocation: Codable {
    let city: String?
    let state: String?
}

struct APITees: Codable {
    let male: [APITeeBox]?
    let female: [APITeeBox]?
}

struct APITeeBox: Codable {
    let tee_name: String?
    let holes: [APIHoleData]?
}

struct APIHoleData: Codable {
    let par: Int?
    let yardage: Int?
    let handicap: Int?
}

// MARK: - API CLIENT

enum GolfCourseAPIClient {
    
    static let apiKey = "6BYEO6KXXAO7RBVKICYTAIKOEA"
    
    // SEARCH
    static func searchCourses(named query: String) async throws -> [CourseSearchItem] {
        var components = URLComponents(string: "https://api.golfcourseapi.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query)
        ]
        
        let url = components.url!
        
        var request = URLRequest(url: url)
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoded = try JSONDecoder().decode(CourseSearchResponse.self, from: data)
        return decoded.courses ?? []
    }
    
    // LOAD COURSE
    static func loadCourse(named query: String) async throws -> Course? {
        let results = try await searchCourses(named: query)
        
        print("Search results:")
        results.forEach {
            print("ID: \($0.id ?? -1), Name: \($0.course_name ?? "nil")")
        }
        
        let bestMatch = results.first {
            ($0.course_name ?? "").lowercased().contains(query.lowercased())
        }
        
        let selected = bestMatch ?? results.first
        
        guard let id = selected?.id else {
            print("No valid course ID")
            return nil
        }
        
        print("Using course ID: \(id)")
        
        return try await getCourse(id: id)
    }
    
    // GET COURSE DETAILS
    static func getCourse(id: Int) async throws -> Course? {
        let url = URL(string: "https://api.golfcourseapi.com/v1/courses/\(id)")!
        
        var request = URLRequest(url: url)
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let raw = String(data: data, encoding: .utf8) {
            print("RAW RESPONSE:")
            print(raw)
        }
        
        // 🔥 FIX: Decode wrapper
        let wrapper = try JSONDecoder().decode(CourseDetailWrapper.self, from: data)
        let decoded = wrapper.course
        
        return mapToCourse(decoded)
    }
    
    // MAP TO APP MODEL
    static func mapToCourse(_ apiCourse: CourseDetailResponse) -> Course? {
        
        let allTees = (apiCourse.tees?.male ?? []) + (apiCourse.tees?.female ?? [])
        
        guard let tee = allTees.first(where: { $0.holes?.isEmpty == false }) else {
            print("No usable tee found")
            return nil
        }
        
        guard let holesData = tee.holes else {
            return nil
        }
        
        let holes: [Hole] = holesData.enumerated().map { index, hole in
            Hole(
                number: index + 1,
                par: hole.par ?? 4,
                frontLatitude: 0,
                frontLongitude: 0,
                centerLatitude: 0,
                centerLongitude: 0,
                backLatitude: 0,
                backLongitude: 0
            )
        }
        
        return Course(
            name: apiCourse.course_name ?? apiCourse.club_name ?? "Unknown Course",
            city: apiCourse.location?.city ?? "",
            state: apiCourse.location?.state ?? "",
            holes: holes
        )
    }
}
