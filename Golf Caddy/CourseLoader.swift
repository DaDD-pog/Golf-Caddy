//
//  CourseLoader.swift
//  Golf Caddy
//
//  Created by Donald Weldon on 4/3/26.
//

import Foundation

enum CourseLoader {
    
    static func loadCourse(named fileName: String) -> Course? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Could not find \(fileName).json in app bundle.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let course = try JSONDecoder().decode(Course.self, from: data)
            return course
        } catch {
            print("Failed to load course \(fileName): \(error.localizedDescription)")
            return nil
        }
    }
}
