//
//  WeeklyPlanEditorSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens

struct WeeklyPlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @State private var editablePlan: [Int: String]
    private let onSave: ([Int: String]) -> Void

    private static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private static let dayNamesDisplay = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(plan: [Int: String], onSave: @escaping ([Int: String]) -> Void) {
        _editablePlan = State(initialValue: plan)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(0..<7, id: \.self) { index in
                    let binding = Binding<String>(
                        get: { editablePlan[index] ?? "" },
                        set: { newValue in
                            if newValue.isEmpty {
                                editablePlan.removeValue(forKey: index)
                            } else {
                                editablePlan[index] = newValue
                            }
                        }
                    )

                    Picker(Self.dayNamesDisplay[index], selection: binding) {
                        Text("None").tag("")
                        ForEach(templates, id: \.name) { template in
                            Text(template.name).tag(template.name)
                        }
                    }
                }
            }
            .navigationTitle("Weekly Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editablePlan)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

#Preview {
    WeeklyPlanEditorSheet(plan: [:]) { _ in }
        .modelContainer(for: WorkoutTemplate.self, inMemory: true)
}
