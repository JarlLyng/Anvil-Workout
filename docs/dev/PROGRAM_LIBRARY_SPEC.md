# Program Library Specification

Research and implementation spec for issue [#18](https://github.com/JarlLyng/Iron-Workout/issues/18) — pre-built workout programs.

This document catalogs the exact set/rep structure for each program so implementation can seed `WorkoutTemplate` records directly. All data here is drawn from publicly documented program structures. Exercise schemes are not copyrightable, but program names, prose descriptions, and specific progression formulas should attribute the original author.

## Implementation status (v1.1)

**Shipped in v1.1** (uses absolute weights only):
- ✅ Starting Strength
- ✅ StrongLifts 5×5
- ✅ Greyskull LP
- ✅ GZCLP
- ✅ Upper/Lower 4-day
- ✅ Push/Pull/Legs 6-day

**Deferred to future releases** (requires new model features):
- ⏸ 5/3/1 BBB, nSuns 5/3/1 LP — need Training Max concept
- ⏸ Madcow 5×5 — needs ramping sets
- ⏸ Texas Method — needs explicit AMRAP distinction
- ⏸ Candito 6-Week — needs multi-week periodization
- ⏸ Sheiko — needs percentage-of-TM weights

See "Open questions for implementation" at the bottom for the model changes each deferred program requires.

## Format convention

Each program entry follows this structure:

- **Attribution** — Author + official resource link
- **Frequency** — Days per week
- **Cycle length** — Typical run-through before reset/advance
- **Progression** — How the working weight increases
- **Workouts** — Each session's exercises with sets × reps

Set/rep notation: `SxR` = Straight sets. `5x5` = 5 sets of 5 reps at same weight. `1x5` = 1 set of 5. `5+` = minimum 5 reps, AMRAP on top.

---

## BEGINNER

### 1. Starting Strength

**Attribution:** Mark Rippetoe — [startingstrength.com](https://startingstrength.com)
**Frequency:** 3 days/week (e.g. Mon/Wed/Fri)
**Cycle length:** Run until lifts stall (typically 3-6 months)
**Progression:** +2.5 kg per session on upper body, +5 kg per session on lower body for first 2 weeks, then +2.5 kg. Deadlift: +5 kg per session.

**Workout A:**
- Back Squat — 3×5
- Overhead Press — 3×5
- Deadlift — 1×5

**Workout B:**
- Back Squat — 3×5
- Bench Press — 3×5
- Barbell Row — 3×5 (Rippetoe prescribes Power Clean; Row is the accepted alternative)

Alternate A/B each session: A → B → A next week B → A → B.

---

### 2. StrongLifts 5×5

**Attribution:** Mehdi Hadim — [stronglifts.com](https://stronglifts.com)
**Frequency:** 3 days/week
**Cycle length:** Run until stall, then deload 10%
**Progression:** +2.5 kg per session on all lifts except Deadlift. Deadlift: +5 kg per session.

**Workout A:**
- Back Squat — 5×5
- Bench Press — 5×5
- Barbell Row — 5×5

**Workout B:**
- Back Squat — 5×5
- Overhead Press — 5×5
- Deadlift — 1×5

Alternate A/B.

---

### 3. Greyskull LP

**Attribution:** John Sheaffer (Johnny Pain) — "Greyskull LP" book
**Frequency:** 3 days/week
**Cycle length:** 8-16 weeks before transitioning to intermediate
**Progression:** +2.5 kg per session on upper body, +5 kg per session on lower body. Last set is AMRAP — if user hits 10+ reps, bump next session's weight by extra 2.5 kg.

**Workout A:**
- Bench Press — 2×5, 1×5+ (AMRAP)
- Barbell Row — 2×5, 1×5+ (AMRAP)
- Back Squat — 2×5, 1×5+ (AMRAP)

**Workout B:**
- Overhead Press — 2×5, 1×5+ (AMRAP)
- Pull-Up or Lat Pulldown — 2×5, 1×5+ (AMRAP)
- Deadlift — 1×5+ (AMRAP)

Alternate A/B.

---

### 4. GZCLP

**Attribution:** Cody Lefever — [r/gzcl wiki](https://www.reddit.com/r/gzcl/wiki/index)
**Frequency:** 4 days/week
**Cycle length:** Run until T1 stalls twice, deload and progress rep scheme
**Progression:** T1 starts at 5×3+; after two failed sessions switch to 6×2+, then 10×1+. T2 starts at 3×10, progresses similarly through 3×8 and 3×6.

**Workout 1 (Squat focus):**
- Back Squat (T1) — 5×3, 1×3+ (AMRAP)
- Bench Press (T2) — 3×10
- Lat Pulldown (T3) — 3×15

**Workout 2 (OHP focus):**
- Overhead Press (T1) — 5×3, 1×3+
- Deadlift (T2) — 3×10
- Barbell Row (T3) — 3×15

**Workout 3 (Deadlift focus):**
- Deadlift (T1) — 5×3, 1×3+
- Back Squat (T2) — 3×10
- Lat Pulldown (T3) — 3×15

**Workout 4 (Bench focus):**
- Bench Press (T1) — 5×3, 1×3+
- Overhead Press (T2) — 3×10
- Barbell Row (T3) — 3×15

---

## INTERMEDIATE

### 5. Upper/Lower 4-day

**Attribution:** Common split; no single author. Popularized in the 2000s-2010s bodybuilding community.
**Frequency:** 4 days/week (e.g. Mon/Tue/Thu/Fri)
**Cycle length:** Ongoing; deload every 6-8 weeks as needed
**Progression:** Double progression — add reps within range, then add 2.5 kg and reset reps.

**Day 1: Upper Strength**
- Bench Press — 4×6
- Barbell Row — 4×6
- Overhead Press — 3×8
- Pull-Up — 3×8
- Barbell Curl — 3×10
- Skullcrusher — 3×10

**Day 2: Lower Strength**
- Back Squat — 4×6
- Romanian Deadlift — 3×8
- Leg Press — 3×10
- Leg Curl — 3×10
- Walking Lunge — 3×10

**Day 3: Upper Hypertrophy**
- Incline Bench Press — 4×8
- Seated Row — 4×8
- Lateral Raise — 4×12
- Lat Pulldown — 3×10
- Hammer Curl — 3×12
- Tricep Pushdown — 3×12

**Day 4: Lower Hypertrophy**
- Front Squat — 4×8
- Romanian Deadlift — 3×10
- Leg Extension — 3×12
- Leg Curl — 3×12
- Hanging Leg Raise — 3×15

---

### 6. Push/Pull/Legs (PPL) 6-day

**Attribution:** Community-developed; widely documented on r/fitness and by Jeff Nippard
**Frequency:** 6 days/week, 1 rest day
**Cycle length:** Ongoing
**Progression:** Double progression within rep range; deload every 8-12 weeks.

**Push Day (Heavy):**
- Bench Press — 4×6-8
- Overhead Press — 3×8-10
- Incline Dumbbell Bench — 3×8-10
- Lateral Raise — 3×12-15
- Tricep Pushdown — 3×10-12
- Skullcrusher — 3×10-12

**Pull Day (Heavy):**
- Deadlift — 3×5
- Barbell Row — 4×6-8
- Pull-Up — 3×8-10
- Face Pull — 3×12-15
- Barbell Curl — 3×8-10
- Hammer Curl — 3×10-12

**Legs Day (Heavy):**
- Back Squat — 4×6-8
- Romanian Deadlift — 3×8-10
- Leg Press — 3×10-12
- Leg Curl — 3×10-12
- Walking Lunge — 3×10

**Push Day (Volume):**
- Incline Bench Press — 4×8-10
- Dumbbell Shoulder Press — 3×10-12
- Cable Fly — 3×12-15
- Lateral Raise — 4×12-15
- Tricep Pushdown — 4×12-15

**Pull Day (Volume):**
- Pendlay Row — 4×8-10
- Lat Pulldown — 4×10-12
- Face Pull — 3×15
- Seated Row — 3×10-12
- Hammer Curl — 4×12

**Legs Day (Volume):**
- Front Squat — 4×8-10
- Romanian Deadlift — 4×8-10
- Leg Extension — 3×12-15
- Leg Curl — 3×12-15
- Hanging Leg Raise — 3×15

---

### 7. Madcow 5×5

**Attribution:** Bill Starr's 5×5 adapted for intermediates by "Madcow" (Glenn Pendlay's student, online)
**Frequency:** 3 days/week (Mon/Wed/Fri)
**Cycle length:** 9-12 weeks
**Progression:** +2.5 kg per week (not per session). Sets 1-4 are ramping warmup sets; set 5 is the working set.

**Monday: Volume**
- Back Squat — 5×5 (ramping: 50%, 62.5%, 75%, 87.5%, 100%)
- Bench Press — 5×5 (ramping)
- Barbell Row — 5×5 (ramping)

**Wednesday: Light**
- Back Squat — 4×5 (ramping, lighter)
- Overhead Press — 4×5
- Deadlift — 4×5

**Friday: Intensity**
- Back Squat — 4×5, 1×3 PR, 1×8 backoff
- Bench Press — 4×5, 1×3 PR, 1×8 backoff
- Barbell Row — 4×5, 1×3 PR, 1×8 backoff

---

### 8. 5/3/1 Boring But Big (BBB)

**Attribution:** Jim Wendler — "5/3/1: The Simplest and Most Effective Training System" book
**Frequency:** 4 days/week
**Cycle length:** 4 weeks per cycle (3 loading + 1 deload), run multiple cycles
**Progression:** After each cycle, increase Training Max by 2.5 kg upper body, 5 kg lower body.

All percentages are of the user's **Training Max** (90% of true 1RM).

**Week 1 main sets (5/5/5+):**
- 5 reps @ 65% TM
- 5 reps @ 75% TM
- 5+ reps @ 85% TM (AMRAP)

**Week 2 main sets (3/3/3+):**
- 3 reps @ 70% TM
- 3 reps @ 80% TM
- 3+ reps @ 90% TM

**Week 3 main sets (5/3/1+):**
- 5 reps @ 75% TM
- 3 reps @ 85% TM
- 1+ reps @ 95% TM

**Week 4 deload:**
- 5 reps @ 40% TM
- 5 reps @ 50% TM
- 5 reps @ 60% TM

**BBB addition (after main sets):** 5×10 of the same lift at 50-60% TM.

**Weekly schedule:**
- Day 1: Overhead Press (main) + Bench Press (BBB)
- Day 2: Deadlift (main) + Back Squat (BBB)
- Day 3: Bench Press (main) + Overhead Press (BBB)
- Day 4: Back Squat (main) + Deadlift (BBB)

Accessories: 3-5 sets of pulling (rows/chins) and core work per session.

---

### 9. nSuns 5/3/1 LP

**Attribution:** Community variant of 5/3/1 developed on r/fitness by user "nSuns"
**Frequency:** 4 or 6 days/week (6-day variant shown)
**Cycle length:** Run until stall, deload 10% and continue
**Progression:** +2.5 kg upper body, +5 kg lower body per week.

Main lift has 9 sets following this scheme (% of TM):
Set 1: 1 rep @ 75% (warmup-ish top single)
Set 2: 1 rep @ 85%
Set 3: 1+ reps @ 95% (AMRAP)
Set 4: 3 reps @ 90%
Set 5: 5 reps @ 85%
Set 6: 3 reps @ 85%
Set 7: 5 reps @ 80%
Set 8: 5 reps @ 75%
Set 9: 5+ reps @ 70% (AMRAP)

**Weekly schedule (6-day):**
- Day 1: Bench (main) + Overhead Press (secondary 3×5)
- Day 2: Squat (main) + Sumo Deadlift (3×5)
- Day 3: Overhead Press (main) + Incline Bench (3×6)
- Day 4: Deadlift (main) + Front Squat (3×5)
- Day 5: Bench (main, variant) + Close-Grip Bench (3×6)
- Day 6: Squat (main, variant) + Back Squat (3×5)

---

## ADVANCED

### 10. Texas Method

**Attribution:** Mark Rippetoe (taught at Wichita Falls Athletic Club, Texas)
**Frequency:** 3 days/week
**Cycle length:** Run until intensity day stalls, then convert to another structure
**Progression:** +2.5 kg per week on intensity day.

**Monday: Volume**
- Back Squat — 5×5 @ 90% of last Friday's 5RM
- Bench Press or Overhead Press — 5×5 @ 90% (alternate weekly)
- Deadlift — 1×5 @ 90%

**Wednesday: Recovery**
- Back Squat — 2×5 @ 80% of Monday's working weight
- Overhead Press or Bench Press — 3×5 (opposite of Monday)
- Chin-Up — 3× bodyweight AMRAP

**Friday: Intensity**
- Back Squat — work up to 1×5 PR
- Bench Press or Overhead Press — work up to 1×5 PR (alternate)
- Power Clean — 6×3 or Deadlift — 1×5 PR (alternate weekly)

---

### 11. Candito 6-Week Program

**Attribution:** Jonnie Candito — free PDF at [canditotraininghq.com](https://canditotraininghq.com)
**Frequency:** 4 days/week
**Cycle length:** 6 weeks, then repeat or switch to another block
**Progression:** Peaking cycle — progresses from hypertrophy → strength → peak.

**Week 1-2: Hypertrophy**
Mostly 4×8-10 at 65-72% with accessories at 3×10-12.

**Week 3: Linear transition**
4×6 at 75-78% on main lifts.

**Week 4-5: Strength**
4×4 to 5×3 at 80-87% on main lifts. Lower volume, more intensity.

**Week 6: Peak**
Test week — work up to new 1RMs on Squat, Bench, Deadlift.

Implementation note: This program's strength is its periodization. Ship as 6 separate "weekly templates" with a "week of cycle" indicator, or as a single template users manually advance.

---

### 12. Sheiko-inspired (Medium Load / Beginner Russian Routine)

**Attribution:** Boris Sheiko — numerous Russian routines; "Sheiko #29" is a common beginner variant
**Frequency:** 3 days/week
**Cycle length:** 4 weeks per block
**Progression:** Follow prescribed percentages; bump Training Max at end of block.

Characterized by high volume at moderate intensity. Example from one workout:

**Workout 1:**
- Bench Press — 5×5 @ 70% TM
- Back Squat — 5×5 @ 70% TM
- Bench Press (variant) — 5×3 @ 75% TM
- Barbell Row — 3×6

**Workout 2:**
- Back Squat — 3×2 @ 80% TM
- Bench Press — 5×3 @ 75% TM
- Deadlift — 3×3 @ 75% TM
- Incline Bench Press — 3×6

**Workout 3:**
- Bench Press — 3×3 @ 80% TM
- Back Squat — 5×5 @ 70% TM
- Overhead Press — 4×6
- Deadlift (variant) — 3×3 @ 70% TM

Note: Full Sheiko programs are highly specific with week-to-week variations. Ship as a simplified 4-week template with a disclaimer linking to the full Sheiko routines for users who want true periodization.

---

## Implementation plan

### Data structure

Each program ships as JSON bundled with the app, matching the existing `WorkoutTemplate` schema:

```swift
struct ProgramLibraryEntry: Codable {
    let id: String                    // stable slug, e.g. "starting-strength"
    let name: String                  // "Starting Strength"
    let author: String                // "Mark Rippetoe"
    let level: ProgramLevel           // .beginner, .intermediate, .advanced
    let goal: ProgramGoal             // .strength, .hypertrophy, .powerlifting
    let daysPerWeek: Int
    let cycleLengthWeeks: Int?        // nil = run until stall
    let progressionDescription: String
    let officialURL: String?          // for attribution
    let workouts: [ProgramWorkout]
}

struct ProgramWorkout: Codable {
    let name: String                  // "Workout A", "Push Day (Heavy)"
    let exercises: [ProgramExercise]
}

struct ProgramExercise: Codable {
    let exerciseName: String          // must match Exercise library
    let sets: Int
    let reps: Int                     // or minReps/maxReps for ranges
    let targetWeightPercent: Double?  // % of TM for 5/3/1 style
    let restSeconds: Int
    let notes: String?                // "Last set AMRAP"
}
```

### Seeding

New service `ProgramLibraryService` mirrors `ExerciseLibraryService`:

- Loads `ProgramLibrary.json` from app bundle on first launch
- Converts each entry into `WorkoutTemplate` + `WorkoutTemplateExercise` records
- Tags template with `isBuiltIn: true` (new field on `WorkoutTemplate`) so user can identify and optionally hide
- Users can duplicate and edit any built-in program — original stays untouched

### UX

- **Workouts tab** gets a new section at top: "Program Library"
- Horizontally scrolling cards grouped by level
- Tap card → full-screen preview with all workouts
- "Add to My Programs" button → copies template into user's library
- First-launch onboarding has a new step: "Pick a program or build your own" with library as default option

### Attribution UI

Each built-in template shows in its detail view:
- Author name
- Small "Inspired by [Author]" badge

Avoid quoting prose from books. `officialURL` is retained in the data model for internal reference but is no longer rendered in the UI or on the marketing site (see issue #28).

---

## Legal notes

- Exercise structures, rep schemes, and percentages are not copyrightable (they are methods/facts)
- **Do not** copy prose descriptions from books (Starting Strength, 5/3/1, etc.)
- **Do** credit authors and link to official resources
- For commercial attribution safety, write program descriptions in our own words based on public knowledge
- Programs from Reddit (GZCLP, nSuns) are community-licensed and can be adapted freely with attribution

---

## Open questions for implementation

1. How to handle warmup sets? Currently `WorkoutTemplateExercise` doesn't distinguish warmup from working sets
2. How to handle AMRAP (as-many-reps-as-possible) sets? Add a flag on `PerformedSet`?
3. How to handle percentage-based programs (5/3/1, nSuns, Sheiko)? Needs a "Training Max" concept — per lift, updated manually
4. How to handle ramping sets (Madcow)? Same as #3 — needs relative weights
5. Should users be able to run multiple programs simultaneously (e.g. lifting + cardio program)?
