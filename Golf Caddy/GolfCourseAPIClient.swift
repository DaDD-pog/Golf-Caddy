import Foundation

struct CourseSearchResponse: Codable {
    let courses: [CourseSearchItem]
}

struct CourseSearchItem: Codable {
    let id: Int
    let club_name: String?
    let course_name: String?
}

struct CourseDetailResponse: Codable {
    let id: Int
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

enum GolfCourseAPIClient {
    
    static let apiKey = "6BYEO6KXXAO7RBVKICYTAIKOEA"
    
    static func searchCourse(named query: String) async throws -> Int? {
        var components = URLComponents(string: "https://api.golfcourseapi.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query)
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Search status: \(httpResponse.statusCode)")
        }
        
        let decoded = try JSONDecoder().decode(CourseSearchResponse.self, from: data)
        return decoded.courses.first?.id
    }
    
    static func getCourse(id: Int) async throws -> Course? {
        let url = URL(string: "https://api.golfcourseapi.com/v1/courses/\(id)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Course detail status: \(httpResponse.statusCode)")
        }
        
        let decoded = try JSONDecoder().decode(CourseDetailResponse.self, from: data)
        return mapToCourse(decoded)
    }
    
    static func loadCourse(named query: String) async throws -> Course? {
        guard let id = try await searchCourse(named: query) else { return nil }
        return try await getCourse(id: id)
    }
    
    static func mapToCourse(_ apiCourse: CourseDetailResponse) -> Course? {
        guard let tee = apiCourse.tees?.male?.first ?? apiCourse.tees?.female?.first else {
            return nil
        }
        
        guard let holesData = tee.holes, !holesData.isEmpty else {
            return nil
        }
        
        let holes: [Hole] = holesData.enumerated().map { index, holeData in
            Hole(
                number: index + 1,
                par: holeData.par ?? 4,
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
