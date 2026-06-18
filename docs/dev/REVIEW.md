# Project Review & Recommendations — Anvil Workout

**Date:** June 18, 2026  
**App Version:** v1.4.0 (Live / Apple Watch & iPad layout updates)  
**Author:** Antigravity (AI Coding Assistant)  

---

## 1. Executive Summary

Anvil Workout has evolved into a highly competitive, local-first strength training application for iOS, iPadOS, and watchOS. The rebrand from *Iron Workout* to *Anvil Workout* is complete, and the marketing site is live on the custom domain. 

The application’s core positioning—**paid one-time purchase, zero subscriptions, no accounts, 100% offline and privacy-first**—is an excellent market differentiator against dominant subscription-based competitors (Strong, Hevy, Fitbod). 

This review provides a deep dive into the code architecture, product concept, and user experience (UX) with concrete, actionable recommendations for future development cycles.

---

## 2. Product Concept & Business Model Recommendations

### 💡 High-Impact: Historical Data Import (Strong/Hevy CSV Import)
* **Concept:** Currently, Anvil Workout supports **CSV Export**, which is great for data portability. However, users migrating from other apps have to start from scratch.
* **Recommendation:** Implement a **CSV Import** feature in Settings. Specifically target the CSV structures of the two largest competitors: **Strong** and **Hevy**. 
* **ASO & GEO Benefit:** This allows you to market the app directly to users looking to escape subscriptions: *"Migrate years of workout history from Strong or Hevy in one click."* This is a massive user acquisition hook.

### 👪 Enable Family Sharing
* **Concept:** Since Anvil Workout is a paid app with a one-time purchase fee, enabling **Family Sharing** in App Store Connect makes it highly attractive for couples and families who train together.
* **ASO Benefit:** Apple explicitly displays a "Supports Family Sharing" badge on the App Store page, which improves purchase conversion rate.

### 📊 Transparent Roadmap on Website
* **Concept:** One-time purchase apps sometimes suffer from the perception that "development will stop." 
* **Recommendation:** Add a simple, public-facing roadmap page (or a section in `support.html`) detailing what features are in active development (e.g. standalone Apple Watch tracking, plate calculator, template folders). This builds trust with potential buyers.

---

## 3. User Experience (UX) & UI Recommendations

### 🏋️ Inline Rest Timer Customization
* **Concept:** Lifters frequently need to adjust rest durations dynamically. For example, if a set was extremely heavy, they might want 3 minutes of rest instead of the pre-planned 90 seconds.
* **Recommendation:** On both the iPhone `ActiveWorkoutView` and the Apple Watch companion view, provide an easy tap target to adjust the rest timer for the *current* interval (e.g., `+30s` / `-30s` buttons) without modifying the underlying template structure.

### 🔢 Plate Calculator Utility
* **Concept:** A classic utility feature that strength trainees love. 
* **Recommendation:** Add a "Plate Calculator" popup or slide sheet inside the active workout set view. The user enters a target barbell weight (e.g., 102.5 kg), and the app displays the exact plate configuration (e.g., two 20kg plates, one 15kg plate, and one 1.25kg plate per side, assuming a 20kg bar).

### 📂 Template Organization (Folders/Tabs)
* **Concept:** Trainees who write custom routines often end up with 10+ templates (e.g., Hypertrophy splits, Powerlifting cycles, Deload templates, Travel routines), cluttering the Workouts tab.
* **Recommendation:** Introduce template tags or folders (e.g., "Hypertrophy", "Powerlifting", "De-load") to allow users to group and filter their workout templates.

### 📝 Media/Illustration Cache (Offline-First)
* **Concept:** A common feature request for exercise libraries is video or GIF guides. Since Anvil is offline-first, you cannot stream heavy video files.
* **Recommendation:** Include highly compressed vector animations or low-res looping Lottie/GIF illustrations locally inside the app for the 25+ built-in exercises, or support adding local photo references to custom exercises.

---

## 4. Code & Architecture Recommendations

### 🔧 SwiftData Storage Key Refactoring (SetType Migration)
* **Concept:** `SetType` raw values are stored in Danish (`"Arbejdssæt"`, `"Opvarmning"`, `"Dropsæt"`) for backwards compatibility, despite the entire UI being in English. 
* **Recommendation:** Prepare a heavyweight SwiftData migration plan (`VersionedSchema` + `MigrationPlan`) to map these database keys to clean, English enum raw values (e.g. `"working"`, `"warmup"`, `"drop"`, `"failure"`). This is critical for future developer velocity and codebase cleanliness.

### 🧪 WatchConnectivity Contract Unit Tests
* **Concept:** The Apple Watch companion app relies on `WatchConnectivityClient` to decode `ActiveWorkoutSnapshot` payloads from the iPhone. If a developer mutates the snapshot model on the phone without updating the watch contract, the watch app will silently break.
* **Recommendation:** Implement integration/unit tests that serialize a mock `ActiveWorkoutSnapshot` on the main app target, transmit it via a mock channel, and verify correct decoding and mapping on the Watch target.

### ⚡ View Splitting Guidelines in Linter
* **Concept:** The project uses the `*Subviews.swift` pattern to bypass Swift compiler bottlenecks.
* **Recommendation:** Add a SwiftLint rule or explicit pre-commit hook that warns if any file inside `Features/` exceeds 250 lines, prompting developers to extract subviews early. This will maintain rapid incremental build times.

---

## 5. Review of Open GitHub Issues

### 🔴 Issue #50: Krydslink — *Solved*
* We have successfully resolved this issue by adding cross-links in the footers of all 7 pages in the marketing site (`docs/`). This is now pushed and live.

### 🔴 Issue #51: Marketing Price as Selling Point — *Partially Solved*
* We updated the meta descriptions and hero sections on the landing pages to emphasize "Subscription-Free" and "One-Time Purchase".
* **Next Step:** You should explicitly state the App Store price (e.g., "$4.99 / 49 DKK") directly on the website landing pages rather than just linking to the App Store. Transparency about the price builds high trust.

### 🔴 Issue #10 & #8: Launch Monitoring & Tracking
* Ensure Sentry is active in production builds (Release scheme) and verify that you do not send user-identifying data in crash reports to maintain your privacy-first promise.
