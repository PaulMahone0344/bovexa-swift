# Design Notes — Liquid Glass restyle (iOS 26)

Referentiedocument voor plak 1-4 van de Liquid Glass restyle-milestone.
Geschreven tijdens plak 1. Lees dit eerst als je aan plak 2, 3 of 4 werkt.

## Omgeving waartegen gecheckt is

- Xcode 26.6 (build 17F113)
- iOS Simulator SDK 26.5 (iPhone 17 Pro, UDID `2EFB7980-2318-4C0E-9C71-3702A664D7B4`)
- `project.yml` → `deploymentTarget.iOS: "26.0"` (was `17.0`, aangepast in plak 1)

## API-check (plak 1, verplicht vooronderzoek)

Elke API hieronder is los getest in een wegwerpbestand
(`Bovexa/_APICheck/APICheck.swift`, één `View` per API, daarna `xcodebuild build`
tegen bovenstaande simulator-destination). Het bestand is na de check verwijderd —
dit zijn de resultaten:

| API | Resultaat | Fallback nodig? |
|---|---|---|
| `.glassEffect(_:in:)` | **Bestaat, compileert.** `Text("Hi").glassEffect(.regular, in: .rect(cornerRadius: 20))` | Nee |
| `GlassEffectContainer` | **Bestaat, compileert.** `GlassEffectContainer { ... }` | Nee |
| `glassEffectID` | **Bestaat, compileert.** `.glassEffectID("id", in: namespace)` | Nee |
| `.buttonStyle(.glass)` | **Bestaat, compileert.** | Nee |
| `.buttonStyle(.glassProminent)` | **Bestaat, compileert.** | Nee |
| `.tabBarMinimizeBehavior` | **Bestaat, compileert.** Getest op native `TabView { Tab("One", systemImage: "1.circle") { ... } }` met `.tabBarMinimizeBehavior(.onScrollDown)`. | Nee |
| `.sensoryFeedback` | **Bestaat, compileert.** `.sensoryFeedback(.success, trigger: someBool)` | Nee |
| `.symbolEffect` | **Bestaat, compileert.** `.symbolEffect(.bounce, value: someBool)` | Nee |
| `.presentationDetents` | **Bestaat, compileert.** (bestond al sinds iOS 16, meegenomen als sanity-check — dit was geen echte iOS 26-only API) | Nee |

**Conclusie: alle 9 API's bestaan en compileren zonder problemen in Xcode 26.6 /
iOS 26.5 SDK.** Er was in plak 1 geen enkele material-fallback nodig. Dat betekent
niet dat fallbacks overal genegeerd mogen worden in plak 2-4 — zie hieronder voor
praktische kanttekeningen per API die pas zichtbaar worden zodra je ze
daadwerkelijk op bestaande schermen toepast (met dynamische content, ForEach-lussen,
sheets, etc. i.p.v. de geïsoleerde test-cases hierboven).

### Praktische kanttekeningen (geen compile-fouten, wel aandachtspunten)

- **`GlassEffectContainer`** groepeert zusterglaselementen zodat ze morphen/
  samensmelten (bv. bij het openen van een sheet of het toggelen van een
  selectie). Gebruik 'm rondom een groep glaselementen op één scherm — niet
  losstaand rondom elk individueel `GlassCard`-gebruik, anders krijg je geen
  samensmelt-effect en voeg je alleen overhead toe. `GlassCard` zelf past dus
  geen eigen container toe; dat gebeurt op schermniveau in plak 2-4 waar
  meerdere glaselementen naast elkaar staan.
- **`.glassEffect(_:in:)`** op een custom shape (`.rect(cornerRadius:)`,
  `Capsule()`, etc.) werkt goed. Let op: als een view ook een eigen
  `.background(...)` of `.clipShape(...)` heeft die conflicteert, kan het glas
  optisch "dubbel" ogen — check dat per call-site in latere plakken.
- **`.buttonStyle(.glass)` / `.glassProminent`** geven zelf al padding/vorm/
  glans; extra custom achtergrond op de knop-content zelf is dan overbodig of
  conflicterend. In plak 1 zijn `GlassProminentButtonStyle`/`GlassSecondaryButtonStyle`
  gebouwd als dunne wrappers hier bovenop (zie `Bovexa/Views/GlassButtonStyles.swift`)
  zodat de teal-merkkleur als tint meegaat.
- **`.tabBarMinimizeBehavior(.onScrollDown)`** vereist de nieuwe `Tab(_:systemImage:)`-
  initializer-stijl binnen `TabView` (niet de oude `.tabItem { }`-stijl). RootTabView
  is in plak 1 herbouwd op basis van deze nieuwe `Tab`-syntax.
- **`.sensoryFeedback`** heeft een `trigger:`-parameter die verandert moet worden
  (bv. via een toggelende `@State`/`Bool` of `.increment` teller) om af te vuren —
  je kunt 'm niet "handmatig aanroepen" zoals een functie. De `Haptics`-helper in
  plak 1 (`Bovexa/Services/Haptics.swift`) biedt daarom een `UIFeedbackGenerator`-
  gebaseerde imperatieve API (`Haptics.selection()`, `.success()`, `.warning()`)
  die vanuit button-actions/ViewModels aangeroepen kan worden zonder een extra
  trigger-state per aanroepplek te moeten beheren. `.sensoryFeedback` an sich was
  dus niet "kapot", maar minder praktisch voor imperatief gebruik vanuit
  store-acties — vandaar de bewuste keuze voor `UIFeedbackGenerator` als
  implementatie, geen availability-fallback.
- **`.symbolEffect`** vereist een `value:`/`isActive:` die verandert om te
  animeren (net als `.sensoryFeedback`). Nog niet toegepast in plak 1 (bouwsteen/
  conventie alleen); plak 2-4 passen 'm toe op favoriet-ster/checkmark-momenten.

## Gekozen aanpak per bouwsteen (plak 1)

- **Achtergrond**: nieuw token `BovexaTheme.Gradients.backgroundSubtle` toegevoegd
  náást de bestaande `BovexaTheme.Gradients.background` (oude token blijft
  ongewijzigd bestaan voor eventuele andere call-sites). `AppBackground` gebruikt
  vanaf plak 1 de subtielere variant. Zie `Bovexa/Theme/Theme.swift`.
- **GlassCard v2**: gebruikt `.glassEffect(.regular, in: RoundedRectangle(...))`
  wanneer beschikbaar; geen availability-fallback nodig want deploymentTarget is
  nu 26.0 (dus altijd beschikbaar op het toestel dat de app draait). Publieke API
  (`radius`/`padding`/`content`) ongewijzigd — bestaande call-sites door de hele
  app blijven werken zonder aanpassing.
- **Knoppen**: `GlassProminentButtonStyle` (teal tint, gebaseerd op
  `.buttonStyle(.glassProminent)`) en `GlassSecondaryButtonStyle` (gebaseerd op
  `.buttonStyle(.glass)`) als losse, herbruikbare `ButtonStyle`-structs in
  `Bovexa/Views/GlassButtonStyles.swift`. Nog niet toegepast op bestaande
  schermen — dat is plak 2-4.
- **Tabbalk**: `RootTabView` gebruikt nu een native `TabView` met `Tab(...)` per
  tab-case en `.tabBarMinimizeBehavior(.onScrollDown)`. De custom
  `FloatingTabBar` is verwijderd. SF Symbols uit het designdocument
  (house/calendar/checklist/briefcase/person.crop.circle) zijn overgenomen i.p.v.
  de oude symbolen (sun.max/calendar/checklist/building.2/person.crop.circle) —
  zie "Afwijkingen" hieronder voor de precieze iconkeuze.
- **Typografie**: nieuwe Dynamic Type-tokens toegevoegd in
  `BovexaTheme.TypeStyle` (bv. `.largeTitle`, `.title2`, `.headline`,
  `.subheadline`, `.footnote` als `Font`-waarden) náást de bestaande
  `BovexaTheme.TypeScale` (px-gebaseerd, blijft intact voor nog
  niet-omgezette schermen in plak 2-4).
- **Haptics**: `Bovexa/Services/Haptics.swift`, een enum met statische methods
  `selection()`, `success()`, `warning()` gebouwd op `UIFeedbackGenerator`
  (`UISelectionFeedbackGenerator` / `UINotificationFeedbackGenerator`). Zie
  hierboven waarom niet op `.sensoryFeedback` gebouwd.

## Afwijkingen / keuzes die expliciet gemeld moeten worden

- **Tab-iconen**: designdocument noemt `house` voor de Vandaag-tab; bestaande
  code gebruikte `sun.max`. Gekozen om het designdocument te volgen (`house`)
  omdat dat expliciet als bindend is aangemerkt. De overige 4 iconen
  (`calendar`/`checklist`/`briefcase`/`person.crop.circle`) — let op: het
  designdocument noemt `briefcase` voor Bedrijf, bestaande code had
  `building.2`. Ook hier is het designdocument gevolgd. Dit is een zuivere
  chrome/icon-wijziging, geen functionele wijziging (dezelfde tab, dezelfde
  view, dezelfde volgorde).
- **`GlassCard` binnenkant**: de kaart gebruikt nu `.glassEffect` in plaats van
  de geschilderde `LinearGradient`-vulling. Optisch dus een merkbaar andere kaart
  (lichter, meer transparant, systeem-glans) — dat is de bedoeling van deze
  milestone. Geen enkele call-site-code is aangepast, alleen het interne
  `GlassCard`-lichaam.
