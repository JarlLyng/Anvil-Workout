# SEO, ASO & GEO Strategy — Anvil Workout

Site: https://anvilworkout.iamjarl.com/  
App Store: **Live — v1.3.0** (1.4.0 i review pr. seneste opdatering)  
Google Search Console: ✅ Connected (begge properties: anvilworkout + legacy ironworkout)  
Last updated: 2026-06-04

---

## 0. First ranking period — GSC data (7. maj – 4. juni 2026)

Site er **indekseret og ranker** — første milestone hit. 28-dages snapshot:

| Metrik | Anvil-site | Iron-site (legacy) |
|---|---:|---:|
| Clicks | 3 | 1 |
| Impressions | 43 | 15 |
| CTR | 6.98% | 6.67% |
| Avg position | 5.0 | 5.9 |
| Pages indexed | 7 | — |

**Per page (Anvil-site):**

| Side | Clicks | Impr | Pos |
|---|---:|---:|---:|
| `/` (root) | 3 | 34 | 3.9 |
| `programs.html` | 0 | 4 | **2.0** ← bedste pos. |
| `no-subscription-workout-app.html` | 0 | 8 | 8.5 |
| `support.html` | 0 | 8 | 7.2 |
| `privacy.html` | 0 | 8 | 7.1 |
| `offline-workout-app.html` | 0 | 7 | 7.3 |
| `apple-health-strength-training.html` | 0 | 7 | 8.4 |

**Sammenligning vs. forrige 28 dage:** P1 var 0 alt — det her er den første ranking-periode for det rebrandede site.

### Insights og handlinger

1. **Queries er under privacy-threshold** — Google viser dem først når volumen er højere. Næste data-trækning om ~30 dage bør afsløre konkrete keywords.
2. **`programs.html` rangerer pos 2** men får kun 4 impressions — søgevolumen for det specifikke tema er lav. Overvej bredere keywords i title/meta.
3. **SEO landing pages rangerer 7-8** og får impressions men 0 clicks — meta description + title CTR-optimering er næste indsatsområde.
4. **Iron-site har stadig residual trafik** (1 click, 15 impr) — tjek at 301-redirects fra ironworkout.iamjarl.com → anvilworkout.iamjarl.com er på plads så link equity ikke mistes.

---

## 1. Product positioning

Anvil Workout er en iOS styrketrænings-app med program builder, workout execution med Live Activity, PR-tracking og Apple Health-integration. One-time purchase, ingen abonnement, ingen konti, 100% offline. SwiftUI + SwiftData.

SEO positioning: **den lokale, abonnementsfrie styrketrænings-app** — differentierer fra Strong, Hevy, Fitbod via nul-abonnement, nul-konto og fuld data-ejerskab.

---

## 2. Hvad der allerede er på plads

### Website (done)

- [x] Landing page (`docs/index.html`) med hero, features, FAQ, screenshots
- [x] Privacy page (`docs/privacy.html`)
- [x] Support page (`docs/support.html`) med FAQ og kontaktinfo
- [x] MobileApplication JSON-LD på homepage (PreOrder, pris tilføjes ved launch)
- [x] FAQPage JSON-LD på homepage (5 spørgsmål)
- [x] BreadcrumbList JSON-LD på alle sider
- [x] WebPage JSON-LD på privacy.html og support.html
- [x] OG tags, Twitter cards, canonical URL
- [x] robots.txt med eksplicit tilladelse til AI-bots (ChatGPT, Claude, Perplexity, Applebot)
- [x] sitemap.xml (3 URL'er: homepage, privacy, support)
- [x] llms.txt for AI-indeksering
- [x] Responsive CSS med dark mode
- [x] Custom domain (anvilworkout.iamjarl.com) med CNAME
- [x] aria-hidden på dekorative SVG-ikoner

### Mangler (not done)

- [ ] apple-itunes-app meta tag (kommenteret ud — tilføj app-id nu hvor appen er live)
- [x] ~~Google Search Console connection~~ ✅ Connected
- [ ] Umami/analytics
- [ ] Favicon, apple-touch-icon, og-image assets
- [x] ~~SEO landing pages~~ ✅ 4 sider indekseret (programs, no-subscription, offline, apple-health)
- [ ] Cross-linking til andre IAMJARL-projekter
- [ ] **NY:** Verificér 301-redirects fra ironworkout.iamjarl.com → anvilworkout.iamjarl.com
- [ ] **NY:** Meta description / title CTR-optimering på landing pages (rangerer pos 7-8 med 0% CTR)

---

## 3. DU SKAL: Pre-launch fixes

### Når appen er klar til release:

1. ~~**Custom domain**~~ ✅ CNAME oprettet, alle URL'er opdateret til anvilworkout.iamjarl.com
2. **apple-itunes-app** → Fjern kommentar, indsæt app-id (appen er nu live — gør det nu)
3. **App Store links** → Opdater alle `href="#"` placeholders
4. ~~**Google Search Console**~~ ✅ Connected, første ranking-data trækkes ind (se sektion 0)
5. **Analytics** → Tilføj Umami
6. **MobileApplication pris** → Tilføj faktisk pris og skift availability fra "PreOrder" til "InStock"
7. **301 redirects** → Verificér ironworkout.iamjarl.com → anvilworkout.iamjarl.com peger korrekt

### Tekniske SEO-fixes (done):

1. ~~**BreadcrumbList JSON-LD**~~ ✅ Tilføjet til alle 3 sider
2. ~~**Privacy JSON-LD**~~ ✅ BreadcrumbList + WebPage tilføjet
3. ~~**Support-side**~~ ✅ `docs/support.html` oprettet

---

## 4. ASO — App Store Optimization

### Forberedt metadata

**App name:** Anvil Workout  
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

- "Anvil Workout supports 1–120 sets per exercise with configurable weight, reps, and rest timers"
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

---

## 11. Google-retningslinjer (reference)

Officiel Google-guidance (ikke andre AI-providers) — relevant for både GEO og vores AI-genererede indhold:

- [AI features and your website](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide)
- [Using AI-generated content](https://developers.google.com/search/docs/fundamentals/using-gen-ai-content)

**Nøglepointer:**

- **Ingen særlig "AI-SEO".** Google's AI-features bygger på deres almindelige ranking. Fundamental SEO vinder: crawlbar, indekserbar, hurtig, people-first indhold, valid structured data. Ingen tricks.
- **`llms.txt` bruges IKKE af Google** (de siger det eksplicit). Vores `docs/llms.txt` beholdes for evt. andre AI-motorer, men regn ikke med den for Google. Hold den faktuelt korrekt.
- **AI-genereret indhold straffes ikke** i sig selv — men kvalitet og menneskelig værdi kræves. At masse-generere tynde sider = "scaled content abuse" (spam-policy). **Konsekvens for §6-landingssider:** hver ny side skal tilføje genuin, unik værdi, ikke være en tynd keyword-variant. Menneske-review før publicering.
- **Undgå side-per-query og over-chunking** af indhold.
- **Hold metadata/structured data korrekt** (titler, descriptions, JSON-LD, `softwareVersion`, featureList) — opdateres ved hver release.
