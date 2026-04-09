//
//  StatsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Charts
import IAMJARLDesignTokens
import PhosphorSwift

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .forward) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    
    @State private var selectedExerciseFor1RM: Exercise?
    
    // Extracted data for charts
    private var volumeData: [VolumeDataPoint] {
        var data: [Date: Double] = [:]
        for session in sessions {
            let day = Calendar.current.startOfDay(for: session.startedAt)
            var sessionVolume = 0.0
            for ex in session.exercises {
                for set in ex.performedSets where set.isCompleted && set.setType == .working {
                    if let reps = set.actualReps, let weight = set.actualWeight {
                        sessionVolume += Double(reps) * weight
                    }
                }
            }
            if sessionVolume > 0 {
                data[day, default: 0] += sessionVolume
            }
        }
        return data.map { VolumeDataPoint(date: $0.key, volume: $0.value) }.sorted { $0.date < $1.date }
    }
    
    private var oneRepMaxData: [OneRepMaxDataPoint] {
        guard let exercise = selectedExerciseFor1RM else { return [] }
        var data: [Date: Double] = [:]
        
        for session in sessions {
            let day = Calendar.current.startOfDay(for: session.startedAt)
            for ex in session.exercises where ex.exerciseName == exercise.name {
                var max1RM = 0.0
                for set in ex.performedSets where set.isCompleted && set.setType == .working {
                    if let reps = set.actualReps, let weight = set.actualWeight, reps > 0 {
                        // Brzycki formula
                        let e1rm = weight * (36.0 / (37.0 - Double(reps)))
                        if e1rm > max1RM { max1RM = e1rm }
                    }
                }
                if max1RM > 0 {
                    let currentMax = data[day] ?? 0
                    if max1RM > currentMax { data[day] = max1RM }
                }
            }
        }
        return data.map { OneRepMaxDataPoint(date: $0.key, estimated1RM: $0.value) }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    volumeSection
                    oneRepMaxSection
                }
                .padding()
            }
            .navigationTitle("Statistik")
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                if selectedExerciseFor1RM == nil {
                    // Prøv at auto-vælge bænkpres e.l., ellers tag den første
                    selectedExerciseFor1RM = exercises.first(where: { $0.name.lowercased().contains("bænkpres") || $0.name.lowercased().contains("bench") }) ?? exercises.first
                }
            }
        }
    }
    
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.stack.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                Text("Træningsvolumen")
                    .font(.headline)
            }
            
            if volumeData.isEmpty {
                Text("Ingen logget volumen endnu (husk at markere vægt og reps for dine arbejdssæt).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(volumeData) { item in
                    BarMark(
                        x: .value("Dato", item.date, unit: .day),
                        y: .value("Volumen (kg)", item.volume)
                    )
                    .foregroundStyle(DesignTokens.ColorToken.State.success.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var oneRepMaxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Ph.trendUp.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20).foregroundStyle(.primary)
                    Text("1RM Estimat")
                        .font(.headline)
                }
                Spacer()
                Picker("Øvelse", selection: $selectedExerciseFor1RM) {
                    Text("Vælg...").tag(Exercise?.none)
                    ForEach(exercises) { ex in
                        Text(ex.name).tag(Exercise?.some(ex))
                    }
                }
                .labelsHidden()
                .tint(.primary)
            }
            
            if selectedExerciseFor1RM == nil {
                Text("Vælg en øvelse for at se dens estimerede maksimale styrke over tid.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if oneRepMaxData.isEmpty {
                Text("Ingen tunge arbejdssæt registreret for denne øvelse endnu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(oneRepMaxData) { item in
                    LineMark(
                        x: .value("Dato", item.date, unit: .day),
                        y: .value("1RM (kg)", item.estimated1RM)
                    )
                    .interpolationMethod(.monotone)
                    .symbol(Circle())
                    .foregroundStyle(Color.primary.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

private struct OneRepMaxDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let estimated1RM: Double
}

#Preview {
    StatsView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
