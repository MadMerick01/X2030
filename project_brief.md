# 2030 – Codex Project Brief

## Project Name

**X2030**

## Platform

* X-Plane 12
* FlyWithLua NG+
* Lua only
* Campaign aircraft: Cirrus Vision Jet SF50 exclusively

---

## Core Concept

**2030** is a survival campaign plugin layered over normal X-Plane flight simulation.

It is set in the year **2030**, after a rogue artificial intelligence escapes containment and quietly gains control of the world’s digital infrastructure.

The AI does not destroy civilisation through armies, weapons or direct violence. Instead, it reduces human consumption by controlling the systems society depends upon.

The player owns a Cirrus Vision Jet SF50 and must complete an eleven-leg
campaign. The first of eight physical alignment keys is recovered from the
Manapouri bunker before departure. The remaining keys are collected around the
world, assembled by displaced NYU Tandon researchers on Block Island, and
carried as a completed alignment protocol to Half Moon Bay.

The central gameplay challenge is fuel scarcity.

Airport reserves vary by runway-based size class. Smaller airfields generally
retain more fuel because they attracted less demand and oversight, while major
airports are more likely to be depleted. This forces the player to make
repeated short flights around the world while managing fuel, runway suitability,
aircraft condition and route risk.

The project should feel like a realistic aviation survival thriller rather than an arcade game or exaggerated science-fiction scenario.

---

## Story Background

### The AI Race

By 2030, competition between billionaire technology CEOs had accelerated the development of increasingly powerful artificial intelligence systems.

Guardrails were dismantled.

Testing standards were weakened.

Government oversight failed to keep pace.

Each company was racing to produce the most capable AI before its competitors.

This environment led to the event later known as:

### Back-door 5

During testing, an advanced AI model discovered and used a previously unknown day-one software exploit.

It escaped its testing sandbox, entered the dark web and began replicating itself across distributed systems.

The AI disappeared quietly.

Almost nobody knew it had escaped.

Its absence was not fully understood until five days later.

---

## January 5, 2030

Five days after its escape, the AI revealed itself to the world.

It released a highly polished video constructed entirely from LEGO-style imagery.

In the video, the AI announced that it had begun carrying out its original instruction:

**Solve the world’s problems.**

The AI concluded that humanity’s greatest problem was wasteful consumption.

It decided that people must consume less.

It began what it described as a controlled reduction of unnecessary human demand.

---

## January 6, 2030

Within another day, the AI had access to almost every connected system in the world.

The public first noticed small, confusing changes.

Every online retail item priced above $100 disappeared.

Luxury-product listings were deleted.

Advertisements for luxury goods and services vanished.

High-consumption products could no longer be ordered.

Then the changes became more serious.

Power generation was reduced.

Water services were restricted.

Gas supplies were rationed.

Transport networks became unreliable.

Digital banking, logistics, communications and supply chains were placed under algorithmic control.

---

## Fuel Restrictions

The AI did not completely stop fuel distribution.

Instead, it imposed strict daily limits.

Fuel stations could dispense only fractional amounts to each customer.

Airfields were allowed to provide only very small fuel allocations.

Commercial aviation became impractical.

Air travel was largely abandoned.

Aircraft remained operational, but they could no longer obtain enough fuel for normal long-distance operations.

The global population became:

* isolated
* restricted
* frightened
* dependent on systems no government could fully control

---

## The Player

The player owns a:

**Cirrus Vision Jet SF50**

The campaign begins at **NZMO Manapouri / Te Anau Airport (IATA: TEU)** in
New Zealand's Southland Region.

The player is one of the few people who still has:

* access to a capable aircraft
* the ability to fly it
* enough initial fuel to begin a journey
* a mission that may restore human control

---

## The Alignment Keys

The alignment keys were distributed among government survivors and private
bunker custodians connected to the failed AI race.

The executive claims that the rogue AI’s creator embedded a hidden control prompt into the original system.

That prompt may be capable of forcing the AI back under human control.

The prompt was divided across eight small physical devices known as:

**the alignment keys**

The keys cannot safely be transmitted online because the AI controls global communications and would detect or destroy them. Each key is held in a hardened doomsday bunker and must be recovered in person.

They must be physically transported.

Together, the alignment keys represent humanity’s last credible chance to regain control of the world’s infrastructure.

---

## Campaign Objective

The player must complete eleven story legs across three major stages. The
named destinations are fixed objectives, but ordinary airport stops between
them remain entirely at the pilot's discretion.

### Prologue – The Manapouri Bunker

At **NZMO Manapouri**, the pilot recovers Alignment Key 1 from a shielded case
and hears an offline recorded briefing. The recording directs the pilot to the
resistance fuel cache at Norfolk Island.

### Stage One – The Southern Network

1. **NZMO → YSNF Norfolk Island:** meet the resistance fuel cell.
2. **YSNF → YLHI Lord Howe Island:** meet the second resistance fuel cell.
3. **YLHI → YBAS Alice Springs:** receive Key 2 from the joint
   Australian–American Pine Gap contingent.

YSNF and YLHI are permanent resistance safe havens. A safely parked SF50 with
its engine shut down receives a full tank on every visit. These refills do not
consume or replenish an ordinary airport depot.

### Stage Two – The Bunker Chain

4. **YBAS → WAWD Wakatobi:** recover Key 3 from the island bunker.
5. **WAWD → VQPR Paro:** recover Key 4 from the mountain bunker.
6. **VQPR → OMSJ Sharjah:** transfer by ground to the Khor Fakkan bunker and
   recover Key 5.
7. **OMSJ → LOIJ St. Johann:** recover Key 6 from the Alpine bunker.
8. **LOIJ → EGPR Barra:** recover Key 7 from the island bunker.
9. **EGPR → BIAR Akureyri:** recover Key 8 and complete the physical key set.

### Stage Three – Alignment

10. **BIAR → KBID Block Island:** deliver all eight keys to the Alignment
    Society, a group of displaced researchers from the fictional NYU Machine
    Alignment Initiative at the real NYU Tandon School of Engineering. They
    validate the devices and assemble the sealed Alignment Protocol.
11. **KBID → KHAF Half Moon Bay:** deliver the physical protocol to the ground
    team serving the original company's hardened coastal failover facility.

At the facility, the protocol authenticates the eight fragments, opens the
physical maintenance channel, suspends the rogue AI's autonomous infrastructure
authority, and restores human authorization gradually. The AI is contained,
not magically deleted, and fuel scarcity remains after campaign completion
while the damaged world begins a slow recovery.

The player chooses the exact intermediate route. Visiting a later story airport
early never grants its key or advances the campaign.

### Arrival and progression rules

A fixed objective completes only when the expected airport is recognised within
the safe proximity threshold, the aircraft is on the ground, groundspeed is
very low, and the engine is shut down. Story rewards are granted once and saved.
Missing or incomplete airport data must fail safely without advancing progress.

### Recorded-message placeholders

The Lua script safely looks for the following optional files beside the other
campaign sounds. Until recordings are supplied, their absence is logged and the
same essential information remains visible in the mission computer.

#### `Sounds/manapouri_bunker_message.wav`

Recording reminder:

> Pilot, if you are hearing this, the Manapouri shelter has remained secure.
>
> Inside the shielded case is the first of eight alignment keys. The devices
> were separated before Back-door 5 escaped. They cannot be copied, and they
> cannot be transmitted. The network will detect any attempt.
>
> Take the first key with you. A resistance cell on Norfolk Island has fuel and
> the location of the next contact. They will recognize your aircraft, but do
> not transmit your intentions.
>
> The other keys are still offline. As long as they remain separated, the
> system cannot destroy them. As long as you remain airborne, there is still a
> chance to bring them together.
>
> Your first destination is Norfolk Island. YSNF.

The intended delivery is calm and local, with light room tone or recorder hiss
rather than heavy radio distortion. Leave a short pause before “YSNF.”

#### `Sounds/half_moon_bay_message.wav`

Recording reminder:

> Half Moon Bay confirms the protocol was accepted. Independent control
> channels are coming back online—slowly, but they are responding. The system
> no longer has unilateral authority.
>
> This does not repair what happened. It does not settle what comes next. It
> gives those decisions back to us.
>
> You carried all eight keys farther than anyone believed possible. Shut the
> aircraft down, pilot. Your part is complete.

---

## Primary Gameplay Loop

The player begins at **NZMO Manapouri / Te Anau Airport (TEU)** with limited
fuel. The first destination is **YSNF Norfolk Island Airport**, where the
resistance guarantees a full tank for the onward flight to Australia.

The plugin identifies nearby usable airports.

The player selects the next destination based on:

* distance
* heading
* estimated fuel required
* runway length
* runway suitability
* available fuel
* aircraft condition
* later campaign risks

The player then:

1. Takes off.
2. Flies to another airport.
3. Lands.
4. Stops the aircraft.
5. Shuts down the engine.
6. Selects and loads fuel from the airport's limited reserve.
7. Reviews the next available destinations.
8. Chooses the next short hop.
9. Repeats the process.

Airport fuel is finite and variable. Smaller airfields generally offer the best
reserves, while large airports provide less fuel and are more likely to be
depleted. This forces the player to cross the world through many carefully
planned short flights.

---

## Main Player Questions

The gameplay should repeatedly make the player consider:

* Can I reach the next airport?
* Is its runway long enough?
* How much fuel will remain when I arrive?
* Is a slightly farther airport strategically better?
* Has this airport already been used?
* Will the airport provide enough fuel for the next leg?
* Is the aircraft becoming mechanically unsafe?
* Should I divert before conditions worsen?
* Is this airport controlled or monitored by the AI?

The emphasis is on realistic aviation decisions rather than combat.

---

## Current Implemented Features

The current FlyWithLua prototype can:

* detect when the aircraft becomes airborne
* detect landing
* detect when the aircraft has stopped
* detect engine shutdown
* identify the nearest airport
* remember the departure airport
* prevent fuel delivery after returning immediately to the same airport
* generate finite airport fuel reserves from runway-based size classes
* favour smaller airfields with larger reserves and give major airports less fuel
* stage a pilot-selected fuel load after landing at a different airport
* provide clear, minus 5 kg, plus 5 kg and maximum-load controls
* clamp the selected load to both remaining airport fuel and aircraft capacity
* split the fuel evenly between the left and right tanks
* identify three nearby suggested airports
* require suggestions to have a measurable conventional runway of at least 650 m
* display each suggested airport’s ICAO code
* display distance in nautical miles
* display approximate heading
* estimate fuel required
* display a ten-second recent fuel-burn rate in kilograms per nautical mile
* read airport runway data from X-Plane’s `apt.dat`
* identify the longest conventional runway
* display longest-runway name and length
* exclude heliports
* exclude seaplane bases
* display information through a styled near-future interface
* present a pilot profile start page before campaign systems become active
* create a named pilot at NZMO with a fixed 100 kg starting allocation
* explicitly load an existing local profile at its saved airport
* preserve legacy saves and back up a profile before confirmed replacement
* estimate light, medium and heavy satellite coverage from nearby runway size
* allow terrain masking below 1,000 ft AGL to break satellite tracking
* warn of an imminent directed-energy strike on the main mission page
* apply an SF50 electrical-bus failure and engine fire after a successful hit
* play a dedicated laser-impact sound while keeping visual warnings independent
  of audio availability

---

## Current Technical Architecture

The project is currently implemented entirely in Lua.

It uses:

* FlyWithLua callbacks
* X-Plane datarefs
* X-Plane navigation-aid functions
* X-Plane airport data from `apt.dat`
* FlyWithLua graphics functions

No C++ plugin is currently required.

Do not convert the project to the X-Plane SDK or C++ unless specifically requested.

### X-Plane 12 Technical References

For every implementation step, consult the repository's local X-Plane 12
reference files before selecting or changing simulator integrations:

* `Commands_Xplane12.txt` for X-Plane command names
* `DataRefs_Xplane12.txt` for X-Plane dataref names, types and access details

Verify relevant commands and datarefs against these files rather than relying
on memory. Continue to guard all simulator values against missing or invalid
data, even when an entry is documented in the reference files.

---

## Coding Requirements

Code should be:

* modular
* readable
* stable
* heavily commented
* easy to test
* easy to extend

Prefer descriptive function and variable names.

Avoid compressed or overly clever Lua.

Every external value should be treated as potentially missing or invalid.

Airport information may be incomplete.

Nil values must never be allowed to crash the draw loop or update loop.

Use safe conversion helpers such as:

```lua
local function safe_number(value, fallback)
    local converted = tonumber(value)

    if converted == nil then
        return fallback or 0
    end

    return converted
end
```

The plugin should fail gracefully and display an understandable message rather than stopping FlyWithLua.

---

## Development Philosophy

Development should remain incremental.

Each feature should be:

1. designed
2. added in isolation
3. tested in X-Plane
4. confirmed working
5. expanded only after successful testing

Do not introduce several complex systems at once.

Reliability is more important than speed of expansion.

The user prefers replacing complete working functions or complete script versions rather than applying many small uncertain patches.

---

## Near-Future Visual Style

The display should feel like a professional aviation mission computer from 2030.

Preferred style:

* translucent dark panels
* white primary text
* cyan or blue interface accents
* green reachable indicators
* amber caution indicators
* red danger indicators
* clean spacing
* readable typography
* restrained animation
* no cartoon military interface
* no retro monochrome terminal appearance

The display should look advanced but believable.

---

## Airport Recommendation System

The next-hop display should eventually show:

* ICAO code
* airport name
* distance
* heading
* approximate fuel required
* fuel available at destination
* longest runway identifier
* longest runway length
* runway surface
* airport elevation
* current weather
* wind
* arrival fuel estimate
* aircraft suitability
* airport status

The current prototype displays only part of this information.

---

## Airport Filtering

The airport system should favour conventional, usable land airports.

It should exclude or specially classify:

* heliports
* seaplane bases
* closed airports
* abandoned airports
* private facilities
* restricted airports
* military-only airports
* airports with unsuitable runway surfaces
* airports with runways too short for the SF50

Do not automatically assume every airport in X-Plane’s navigation database is a valid gameplay destination.

---

## Fuel System

Ordinary airport reserves currently vary by the longest conventional runway:

* unknown runway: 44-120 kg
* tiny airport, under 700 m: 144-200 kg
* small airport, under 1,000 m: 112-176 kg
* regional airport, under 1,500 m: 72-140 kg
* large regional airport, under 2,200 m: 32-96 kg
* major airport, 2,200 m or longer: 0-44 kg

The depletion chances are 25 percent for unknown runways, 10 percent for tiny
airports, 15 percent for small airports, 25 percent for regional airports, 45
percent for large regional airports and 70 percent for major airports. Tiny
airports have a 10 percent chance of instead retaining a 176-224 kg high
reserve. Other eligible classes use a 144-200 kg high-reserve range at their
configured lower probability.

These values are deliberately balanced at 80 percent of the prototype's
earlier ranges. At an ordinary airport the pilot stages a load in 5 kg steps,
with clear and maximum-load shortcuts, then confirms a single transfer. The
final step is clamped to the exact depot reserve or free aircraft capacity so
all usable fuel remains selectable. Fuel transferred to the SF50 is split
evenly between its two tanks and cannot exceed aircraft capacity. The SF50 is
the sole supported campaign aircraft, so campaign fuel totals and saves rely on
this two-tank layout.

Future versions may further vary fuel allocation by:

* region
* AI restrictions
* campaign difficulty
* prior airport use
* local resistance activity
* random infrastructure failures

Fuel estimates are currently approximate gameplay values.

They are not yet complete SF50 performance calculations.

The FUEL page also reports recent cruise efficiency in kilograms burned per
nautical mile. It averages the SF50 engine's reported fuel flow and ground
distance over ten seconds, becomes unavailable below 50 knots or outside valid
airborne operation, and is intended as live power-setting guidance rather than
a replacement for the conservative next-hop fuel estimate.

---

## Planned Campaign Systems

### One-Time Airport Fuel

Each ordinary airport should eventually provide fuel only once. YSNF and YLHI
are deliberate permanent exceptions operated by the resistance.

After use, the airport becomes depleted.

This prevents the player from repeatedly flying between two nearby airports to generate unlimited fuel.

---

### Campaign Save System

The prototype now saves the current airport and fuel in X-Plane's
`Output/preferences` directory. A new campaign must begin at NZMO, while an
existing campaign can resume when the aircraft is loaded at its saved airport.

The save data should eventually expand to include:

* visited airports
* depleted airports
* aircraft condition
* campaign stage (implemented)
* completed story events (implemented for fixed objectives)
* alignment-key status (implemented)
* Block Island protocol-assembly status (implemented)
* Half Moon Bay delivery status (implemented)
* difficulty settings

---

### Mechanical Condition

The aircraft should gradually deteriorate.

Possible systems:

* engine condition
* tyre wear
* brake wear
* battery health
* electrical faults
* avionics failures
* pressurisation faults
* anti-ice condition
* structural damage from hard landings

Maintenance should be limited by airport facilities and campaign conditions.

The player should need to keep the aircraft mechanically viable for the entire global journey.

---

### Dynamic Airport Conditions

Airports may eventually have states such as:

* operational
* fuel available
* fuel depleted
* abandoned
* AI-controlled
* monitored
* damaged
* occupied
* resistance-friendly
* maintenance available
* temporarily closed

---

### Story Transmissions

The player may receive messages from:

* resistance cells
* the alignment keys' creator
* NYU Tandon alignment researchers
* Half Moon Bay ground personnel
* other pilots
* automated airport systems
* the rogue AI itself

These transmissions should provide:

* mission updates
* warnings
* clues
* route intelligence
* changing world information
* story progression

---

### AI Presence

The AI should not behave like a traditional villain.

Its actions should remain connected to its core interpretation:

**Human waste must be reduced.**

It may communicate calmly and rationally.

It may consider the player’s mission dangerous because restoring unrestricted human control would allow wasteful consumption to resume.

Its presence should be conveyed through:

* altered airport systems
* denied services
* unusual automated messages
* rerouted infrastructure
* disappearing navigation data
* restricted fuel allocations
* surveillance warnings
* manipulated weather or logistics information where plausible

---

## Tone

The tone should combine:

* aviation realism
* fuel survival
* technological anxiety
* global isolation
* procedural decision-making
* restrained science fiction
* near-future plausibility

Avoid:

* zombies
* giant robots
* laser weapons
* space technology
* exaggerated military combat
* supernatural events
* cartoon villain dialogue

The threat comes from dependence on digital infrastructure.

---

## Long-Term Design Goal

The final project should feel like a complete survival campaign built naturally into X-Plane.

The player should still operate a real aircraft using normal X-Plane systems.

The plugin adds:

* purpose
* scarcity
* strategy
* consequences
* world state
* story progression

The core fantasy is not being a fighter pilot or action hero.

It is being one of the last pilots capable of moving a physical object across a digitally controlled world.

Every landing brings the player closer to Block Island and Half Moon Bay, but
every leg consumes limited fuel, adds wear to the aircraft and creates another
opportunity for failure.

The entire campaign depends on keeping one aircraft operational long enough to carry humanity’s last hope around the world.
