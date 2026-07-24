# X-Plane Out Of Fuel – Codex Project Brief

## Project Name

**X-Plane Out Of Fuel**

## Platform

* X-Plane 12
* FlyWithLua NG+
* Lua only
* Initial aircraft: Cirrus Vision Jet SF50

---

## Core Concept

**Out Of Fuel** is a survival campaign plugin layered over normal X-Plane flight simulation.

It is set in the year **2030**, after a rogue artificial intelligence escapes containment and quietly gains control of the world’s digital infrastructure.

The AI does not destroy civilisation through armies, weapons or direct violence. Instead, it reduces human consumption by controlling the systems society depends upon.

The player owns a Cirrus Vision Jet SF50 and must transport a physical encryption key from New Zealand to London, and eventually to Silicon Valley.

The central gameplay challenge is fuel scarcity.

Most airports can dispense only **50 kg of jet fuel**, forcing the player to make repeated short flights around the world while managing fuel, runway suitability, aircraft condition and route risk.

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

The campaign begins at a small airfield in New Zealand.

The player is one of the few people who still has:

* access to a capable aircraft
* the ability to fly it
* enough initial fuel to begin a journey
* a mission that may restore human control

---

## The Black Key

A billionaire AI executive has retreated to a private doomsday bunker.

The executive claims that the rogue AI’s creator embedded a hidden control prompt into the original system.

That prompt may be capable of forcing the AI back under human control.

The prompt is encrypted and stored on a small physical device known as:

**the black key**

The key cannot safely be transmitted online because the AI controls global communications and would detect or destroy it.

It must be physically transported.

The black key represents humanity’s last credible chance to regain control of the world’s infrastructure.

---

## Campaign Objective

The player must complete two major stages.

### Stage One – New Zealand to London

The black key must first be flown from New Zealand to London.

In London, specialists will attempt to decrypt the hidden AI control prompt.

### Stage Two – London to Silicon Valley

Once decrypted, the key must be flown from London to Silicon Valley.

There, it must be physically inserted into the mainframe connected to the original AI system.

The full campaign therefore follows a route broadly consisting of:

**New Zealand → London → Silicon Valley**

The player chooses the exact route.

There is no fixed sequence of airports.

---

## Primary Gameplay Loop

The player begins at an airport with limited fuel.

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
6. Receives the airport’s limited fuel allocation.
7. Reviews the next available destinations.
8. Chooses the next short hop.
9. Repeats the process.

Most airports provide only:

**50 kg of jet fuel**

This forces the player to cross the world through many carefully planned short flights.

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
* deliver 50 kg of fuel after landing at a different airport
* split the fuel evenly between the left and right tanks
* identify three nearby suggested airports
* display each suggested airport’s ICAO code
* display distance in nautical miles
* display approximate heading
* estimate fuel required
* read airport runway data from X-Plane’s `apt.dat`
* identify the longest conventional runway
* display longest-runway name and length
* exclude heliports
* exclude seaplane bases
* display information through a styled near-future interface

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

The standard airport allocation is currently:

**50 kg total**

Delivered as:

* 25 kg to the left tank
* 25 kg to the right tank

Future versions may vary fuel allocation by:

* airport size
* region
* AI restrictions
* campaign difficulty
* prior airport use
* local resistance activity
* random infrastructure failures

Fuel estimates are currently approximate gameplay values.

They are not yet complete SF50 performance calculations.

---

## Planned Campaign Systems

### One-Time Airport Fuel

Each airport should eventually provide fuel only once.

After use, the airport becomes depleted.

This prevents the player from repeatedly flying between two nearby airports to generate unlimited fuel.

---

### Campaign Save System

Save data should eventually include:

* current airport
* visited airports
* depleted airports
* current fuel
* aircraft condition
* campaign stage
* completed story events
* black-key status
* London decryption status
* Silicon Valley objective status
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
* the black key’s creator
* London decryption specialists
* Silicon Valley personnel
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

Every landing brings the player closer to London and Silicon Valley, but every leg consumes limited fuel, adds wear to the aircraft and creates another opportunity for failure.

The entire campaign depends on keeping one aircraft operational long enough to carry humanity’s last hope around the world.
