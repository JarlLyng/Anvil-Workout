# Marketing Review & Optimization Findings — Anvil Workout

**Date:** July 25, 2026  
**App Version:** v1.7.1  
**Target Domain:** https://anvilworkout.iamjarl.com/  
**Author:** Antigravity (AI Coding Assistant)  

---

## 1. Executive Summary

Anvil Workout's marketing site (`docs/`) has strong technical foundations: zero-dependency hand-authored HTML, clean CSS, structured data (JSON-LD), `llms.txt`, `sitemap.xml`, and explicit `robots.txt` permissions for AI search bots (GEO). 

However, a thorough audit against the project's **Voice Rules** (in `AGENTS.md` / `VOICE.md`), recent **v1.5.0–v1.7.1 feature releases**, and **open GitHub issues** reveals significant opportunities to boost conversion, fix brand voice violations, and rank higher in search engines.

---

## 2. Voice & Copy Audit (Violations & Fixes)

According to `AGENTS.md` (line 42), all public copy must adhere to `VOICE.md` with hard rules:
- **No em-dashes (`—`)**
- **No bullet lists in public copy**
- **Minimal emojis**
- **Avoid AI-sounding phrasing**

### Findings:
1. **Em-dashes (`—`) in Public Copy:**
   * Found in `apple-health-strength-training.html` (lines 102, 109, 130, 143)
   * Found in `index.html` (lines 59, 84, 173, 222)
   * Found in `no-subscription-workout-app.html` (lines 136, 142, 145, 151, 153, 156, 220, 221)
   * Found in `offline-workout-app.html` (lines 122, 130, 136, 139, 145, 148, 149, 192)
   * Found in `programs.html` (lines 28, 38, 69, 160, 239, 310, 327, 343, 364, 373, 377, 382)
   * *Action:* Replace em-dashes with colons, periods, or clean commas.

2. **Bullet Lists (`<ul>`/`<li>`) in Landing Pages:**
   * `no-subscription-workout-app.html`, `offline-workout-app.html`, and `apple-health-strength-training.html` rely heavily on standard HTML bullet lists (`<ul>/<li>`) to present features and comparisons.
   * *Action:* Refactor bullet lists into clean paragraph narrative blocks or card grid components (e.g. `.feature-card` or `.info-box`).

3. **AI-sounding / Generic Phrasing:**
   * Phrases like *"is an afterthought"*, *"notoriously hard to measure"*, *"distraction-free gym experience"* can sound formulaic.
   * *Action:* Replace with concrete, athlete-direct language: *"built for lifters who just want to log their sets and get on with their workout."*

---

## 3. Product Messaging & Feature Highlights

### 💡 High Conversion Hook: Strong & Hevy CSV Import (v1.5.0)
* **Status:** Implemented in v1.5.0 (`0a91b7c`), but barely visible on the marketing site.
* **Finding:** Lifters looking for a "no-subscription workout app" are usually current users of Strong or Hevy who feel trapped by monthly fees. 
* **Recommendation:** Put **"Import history from Strong & Hevy in one tap"** as a highlighted banner/feature card on `index.html` and `no-subscription-workout-app.html`.

### 🔢 New Core Features Missing from Homepage Feature Grid
* **Status:** In v1.5.0–v1.6.0, Anvil added **Plate Calculator**, **RPE Tracking**, and **Template Tags**.
* **Finding:** The homepage feature grid currently highlights generic points like "Track Progress" and "Smart Dashboard".
* **Recommendation:** Update the 6-card feature grid to feature **Plate Calculator** (calculates exact barbell plates) and **Strong/Hevy Import**, which are high-intent features for serious lifters.

### 🏷️ Explicit Pricing (GitHub Issue #51)
* **Status:** Open Issue #51 (*"Marketing: Gør engangsprisen til et eksplicit salgsargument"*).
* **Finding:** The site states *"One-time purchase"*, but never names the actual price ($4.99 / 49 DKK).
* **Recommendation:** Add a prominent price callout badge on the hero section and CTA section (e.g., **"$4.99 once. Yours forever. No subscription."**). Showing the exact price eliminates purchase friction.

---

## 4. SEO, GEO & AI Readiness

### 🤖 LLM Indexing (`docs/llms.txt`)
* `llms.txt` is up-to-date with Apple Watch, iPad, supersets, and offline architecture.
* *Improvement:* Add explicit mentions of Strong/Hevy CSV import, RPE tracking, and Plate Calculator to `llms.txt` so Perplexity, ChatGPT, and Gemini cite Anvil when users search *"workout app that imports Strong CSV"* or *"workout app with plate calculator no subscription"*.

### 🔍 JSON-LD Schemas
* `MobileApplication` schema on `index.html` is valid and contains `operatingSystem: "iOS, watchOS, iPadOS"`.
* *Improvement:* Update `featureList` array in `index.html` JSON-LD to remove em-dashes and include Strong/Hevy import, Plate Calculator, and RPE tracking.

### 🌐 Cross-Linking & Footer Links
* Footers on all 7 HTML pages contain cross-links to `iamjarl.com`, `WODrounds`, `Walkful`, `Wean Nicotine`, and `Made by Human`.
* In-app Settings features an *"Also from IAMJARL"* section (`30b2e63`).

---

## 5. Visual Assets & Media

### 📱 Missing Apple Watch & iPad Visuals
* **Finding:** The site hero and screenshots gallery currently show only iPhone mockups (`dashboard.png`, `programs.png`, `history.png`, `exercises.png`, `stats.png`).
* **Recommendation:** Add a visual mockup of the **Apple Watch companion app screen** (rest countdown / set logging) and **iPad dual-column active workout screen** to the screenshots gallery or feature section.

---

## 6. Actionable Checklist for Next Marketing Touch

- [ ] **Voice Audit Pass:** Remove all em-dashes (`—`) from all 7 HTML pages in `docs/`.
- [ ] **Copy Restructure:** Convert bullet lists (`<ul>/<li>`) in body copy into paragraph blocks or card grids.
- [ ] **Explicit Pricing (#51):** Add "$4.99 once. No subscription." badge to the hero CTA buttons.
- [ ] **Feature Highlights:** Add Strong & Hevy CSV import and Plate Calculator to the homepage features grid.
- [ ] **AI Metadata Update:** Refresh `llms.txt` and `index.html` JSON-LD schema with CSV import and Plate Calculator.
- [ ] **Watch & iPad Screenshots:** Add Apple Watch and iPad mockup images to `docs/screenshots/`.
