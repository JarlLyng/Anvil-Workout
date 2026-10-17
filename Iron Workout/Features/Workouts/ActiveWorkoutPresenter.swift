//
//  ActiveWorkoutPresenter.swift
//  Anvil Workout
//
//  The workout on screen, held above the iPhone and iPad layouts (#104). `ContentView` swaps a
//  tab bar for a sidebar when the width class changes: folding or unfolding an iPhone Duo, or
//  resizing an iPad window. Each layout builds its own Home and program screens, so a workout
//  presented from one of them went away with it, still open, and showed up on Home as if it
//  were done. Held here and presented from `ContentView`, it stays on screen through the swap.
//  Only End closes it.
//

import Observation

@Observable
final class ActiveWorkoutPresenter {
    /// The workout running on screen, or nil.
    var session: WorkoutSession?
}
