# SEO, ASO & GEO Strategy — Iron Workout

Site: https://jarllyng.github.io/IronFlow/ (TBA: ironworkout.iamjarl.com)  
App Store: Endnu ikke udgivet  
Google Search Console: Ikke connected endnu  
Last updated: 2026-04-15

---

## 1. Product positioning

Iron Workout er en iOS styrketrænings-app med program builder, workout execution med Live Activity, PR-tracking og Apple Health-integration. One-time purchase, ingen abonnement, ingen konti, 100% offline. SwiftUI + SwiftData.

SEO positioning: **den lokale, abonnementsfrie styrketrænings-app** — differentierer fra Strong, Hevy, Fitbod via nul-abonnement, nul-konto og fuld data-ejerskab.

---

## 2. Hvad der allerede er på plads

### Website (done — minimalt)

- [x] Landing page (`docs/index.html`) med hero, features, FAQ, screenshots
- [x] Privacy page (`docs/privacy.html`)
- [x] MobileApplication JSON-LD på homepage (pris: 0, PreOrder)
- [x] FAQPage JSON-LD på homepage (5 spørgsmål)
- [x] OG tags, Twitter cards, canonical URL
- [x] robots.txt med eksplicit tilladelse til AI-bots (ChatGPT, Claude, Perplexity, Applebot)
- [x] sitemap.xml (2 URL'er)
- [x] llms.txt for AI-indeksering
- [x] Responsive CSS med dark mode

### Mangler (not done)

- [ ] Custom domain (ironworkout.iamjarl.com)
- [ ] apple-itunes-app meta tag (kommenteret ud)
- [ ] Google Search Console connection
- [ ] Umami/analytics
- [ ] BreadcrumbList JSON-LD
- [ ] JSON-LD på privacy.html
- [ ] Support-side
- [ ] SEO landing pages
- [ ] Cross-linking til andre IAMJARL-projekter

---

## 3. DU SKAL: Pre-launch fixes

### Når appen er klar til release:

1. **Custom domain** → Opret CNAME for ironworkout.iamjarl.com, opdater alle URL'er (canonical, OG, sitemap, robots.txt)
2. **apple-itunes-app** → Fjern kommentar, indsæt app-id
3. **App Store links** → Opdater alle `href="#"` placeholders
4. **Google Search Console** → Connect og verificer
5. **Analytics** → Tilføj Umami
6. **MobileApplication pris** → Opdater price fra "0" til faktisk pris, og availability fra "PreOrder" til "InStock"

### Tekniske SEO-fixes (kan gøres nu):

1. **BreadcrumbList JSON-LD** → Tilføj til homepage og privacy
2. **Privacy JSON-LD** → Tilføj mindst BreadcrumbList
3. **Support-side** → Opret `support.html`

---

## 4. ASO — App Store Optimization

### Forberedt metadata

**App name:** Iron Workout  
**Subtitle:** `Plan and Track Workouts` (fra README) eller `Track Lifts, No Subscription` (fra strategi)  
**Keywords (98 tegn):**
```
strength training,workout tracker,program builder,Apple Health,lifting,personal records,gym,offline
```

### DU SKAL: Skandinaviske storefronts

**Dansk:**
```
styrketræning,træningslog,program builder,Apple Health,vægtløftning,personlige rekorder,gym,offline
```

**Svensk:**
```
styrketräning,träningslogg,program builder,Apple Health,viktlyftning,personliga rekord,gym,offline
```

**Norsk:**
```
styrketrening,treningslogg,program builder,Apple Health,vektløfting,personlige rekorder,gym,offline
```

**Tysk:**
```
krafttraining,trainingsprotokoll,programm,Apple Health,gewichtheben,persönliche rekorde,fitnessstudio
```

### Screenshots-strategi

- Screenshot 1: "Build custom workout programs"
- Screenshot 2: "Track sets, reps, and weight in the gym"
- Screenshot 3: "Live Activity — workout on Lock Screen"
- Screenshot 4: "Personal records detected automatically"
- Screenshot 5: "Apple Health integration"

---

## 5. Keyword-strategi

### Tier 1 — Højeste relevans

- strength training app
- workout program builder
- gym workout logger
- exercise tracker iOS
- lifting app no subscription

### Tier 2 — Informationelle

- best strength training program for beginners
- how to track personal records
- apple health workout tracker
- custom workout program builder

### Tier 3 — Differentiering

- offline strength training app
- workout app no subscription
- local-first fitness app
- workout app no account

### Tier 4 — Skandinavisk

- styrketræning app (DA)
- styrketräning app (SV)
- styrketrening app (NO)

---

## 6. DU SKAL: Udvid website

### Landing pages at oprette (post-launch)

1. **`/programs`** — Guide til træningsprogrammer (5x5, Upper/Lower, PPL) med ItemList JSON-LD
2. **`/apple-health-strength-training`** — "Apple Health for Serious Lifters" — informationel, høj volumen
3. **`/offline-workout-app`** — differentierings-side mod cloud-baserede apps

### Cross-linking

Tilføj til footer:

- [iamjarl.com](https://iamjarl.com) — portfolio
- [WODrounds](https://wodrounds.iamjarl.com) — relateret fitness-app (timer)
- [Wean Nicotine](https://weannicotine.iamjarl.com) — sundhed
- [Made by Human](https://madebyhuman.iamjarl.com) — IAMJARL brand

NB: Link IKKE til Beef — den er ikke udgivet endnu.

---

## 7. GEO — Generative Engine Optimization

### Hvad der er på plads

- llms.txt med fuld produktbeskrivelse — ekstremt godt for AI-indeksering
- robots.txt der eksplicit tillader AI-bots (ChatGPT, Claude, Perplexity, Applebot, Google-Extended)
- FAQPage JSON-LD med 5 relevante spørgsmål

### DU SKAL: Optimér for AI-passage-ekstraktion

**Target queries for AI-citation:**

- "Best strength training app no subscription" → homepage
- "Offline workout tracker for iPhone" → homepage
- "How to build a custom workout program" → (ny /programs side)
- "Apple Health strength training integration" → (ny landing page)

### Tilføj konkrete datapunkter:

- "Iron Workout supports 1–120 sets per exercise with configurable weight, reps, and rest timers"
- "One-time purchase — no subscription, no in-app purchases, no ads"
- "Live Activity shows current exercise, time, and set progress on Lock Screen and Dynamic Island"
- "All data stored locally with SwiftData — no cloud, no account"
- "CSV export for full data portability"

---

## 8. Indhold der mangler

### P1 — Ved launch

- Custom domain + DNS
- Google Search Console
- Analytics
- Support-side
- App Store metadata finalisering
- Alle pre-launch fixes fra sektion 3

### P2 — Post-launch (første måned)

- SEO landing pages (programs, apple health, offline)
- Product Hunt launch
- Reddit posts (r/fitness, r/weightroom, r/powerlifting)
- Cross-linking fra andre IAMJARL-sites

### P3 — Nice to have

- Blog: "How to Choose a Strength Training Program"
- Blog: "Why Your Workout Data Should Stay on Your Phone"
- YouTube demo video
- Hacker News Show HN

---

## 9. Where to make noise

### Reddit

- **r/fitness** (~4.5M) — "Built a minimal strength app, no subscription"
- **r/weightroom** (~250k) — custom program builder, PR tracking
- **r/powerlifting** (~200k) — periodization, PR tracking
- **r/bodybuilding** (~300k) — PPL, Upper/Lower splits
- **r/homegym** (~500k) — offline workout app
- **r/AppleWatch** (~300k) — Apple Health integration
- **r/swiftui** (~100k) — SwiftUI + SwiftData arkitektur

### Andre kanaler

- **Product Hunt** — "Strength training without compromise"
- **Hacker News** — Show HN: Local-first fitness with SwiftUI
- **Indie Hackers** — build-in-public historie
- **Starting Strength forums, T-Nation** — styrketrænings-community

---

## 10. Monitoring (aktiver ved launch)

- **Google Search Console**: Ugentlig — impressions, clicks, crawl errors
- **Umami/Analytics**: Sidevisninger, referral sources
- **App Store Connect**: Downloads, keyword rankings, conversion rate
- **Nøgletal**: Branded search volumen, organic trafik, App Store reviews
