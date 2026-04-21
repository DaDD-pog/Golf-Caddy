import SwiftUI

struct CoursePickerView: View {
    
    let courses: [DetectedCourse]
    let onSelect: (DetectedCourse) -> Void
    let onManualRound: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section("Nearby Courses") {
                    ForEach(courses) { course in
                        Button {
                            onSelect(course)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(course.name)
                                    .font(.headline)
                                
                                Text("\(Int(course.distance)) meters away")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Other Option") {
                    Button {
                        onManualRound()
                    } label: {
                        HStack {
                            Image(systemName: "map")
                            Text("Start Manual Round")
                        }
                    }
                }
            }
            .navigationTitle("Select Course")
        }
    }
}
