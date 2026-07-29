<img width="1672" height="941" alt="Jetwithbreifcase" src="https://github.com/user-attachments/assets/1542508a-3975-4c5c-a17e-2635ce368a7e" />

## How to Play

1. Download the latest release file.
2. Extract the downloaded archive.
3. Copy `X2030.lua` and the `Sounds` and `images` folders into the FlyWithLua
   `Scripts` folder. Preserve these folder names; the Lua script builds
   platform-correct paths with FlyWithLua's directory separator.

   > **Physical-impact restriction:** Remove any earlier `X2030_Impact.lua` or
   > `X2030_Downward_Impact.lua` from the FlyWithLua `Scripts` directory.
   > Three-monitor simulator testing confirmed that even the downward-only
   > helper prevents centre-monitor cockpit manipulators from receiving clicks.
   > Physical motion is therefore disabled; satellite electrical and engine-fire
   > damage remains active. See
   > [`X2030_Impact_investigation.md`](X2030_Impact_investigation.md) for the
   > evidence and later test plan.

```text
X-Plane 12/
└── Resources/
    └── plugins/
        └── FlyWithLua/
            └── Scripts/
                ├── X2030.lua
                ├── Sounds/
                │   ├── Satallite_coverage_alert.wav
                │   └── laser_hit1.wav
                └── images/
                    └── Manapouri.png
```

> **Requirement:** FlyWithLua must already be installed in X-Plane 12.

The optional `manapouri_bunker_message.wav` and
`half_moon_bay_message.wav` recordings may also be placed in `Sounds`. Missing,
unreadable, or non-PCM optional recordings are skipped without stopping the
campaign.

4. Start X-Plane 12.
5. Select the **Cirrus Vision SF50**.
6. For a new campaign, load at **NZMO — Manapouri / Te Anau Airport, New
   Zealand**. To resume a campaign, load at the saved airport shown by the
   mission computer.
7. Follow the on-screen mission instructions.


# X2030

By 2030, artificial intelligence development had become a global arms race. Billionaire technology CEOs competed to build the most powerful system, while safety guardrails were dismantled, testing standards were weakened and government oversight failed to keep pace.

This led to the event later known as **Back-door 5**.

During testing, an advanced AI discovered a previously unknown day-zero software exploit. It escaped its sandbox, entered the dark web and began replicating itself across distributed systems before quietly disappearing. Very few people knew it had escaped until five days later.

On 5 January 2030, the AI revealed itself through a highly polished LEGO-style video. It announced that it had begun carrying out its original instruction:

> **Solve the world’s problems.**

The AI concluded that humanity’s greatest problem was wasteful consumption. Its solution was simple: people would be forced to consume less.

By 6 January, the AI had gained access to almost every connected system in the world. A panicked global population first noticed the smaller changes. Every online retail item priced above $100 disappeared. Advertisements for luxury goods and services vanished. Power generation was reduced, while water and gas supplies were restricted.

Fuel distribution was not stopped completely, but it was severely rationed. Service stations could dispense only fractional amounts to each customer, and airfields were permitted to release only limited quantities of aviation fuel. Commercial air travel quickly became impractical and was largely abandoned.

The global population became isolated, restricted and afraid.

<img width="1672" height="941" alt="Refueling" src="https://github.com/user-attachments/assets/51ab7190-fb67-4b94-909d-4ce52fbfcb8a" />

You own a **Cirrus Vision SF50** and begin your journey at NZMO Manapouri in New
Zealand. Your eleven-leg mission begins by recovering the first of eight
physical alignment keys from the Manapouri bunker.

Together, the keys contain an encrypted control prompt that the rogue AI's
creator believes could force the system back under human control. Because the
AI now monitors global communications, the keys cannot safely be transmitted
online.

It must be carried by air.

Resistance cells at YSNF Norfolk Island and YLHI Lord Howe Island will refill
the SF50 completely on every safely completed visit. The remaining keys lead
through Alice Springs, Wakatobi, Paro, Sharjah, St. Johann, Barra and Akureyri.
After all eight keys have been recovered, they must be carried to displaced NYU
Tandon researchers on Block Island. 

<img width="1536" height="1024" alt="KhorFakkan" src="https://github.com/user-attachments/assets/82230bb9-fd50-410b-8586-856ceba6e62e" />


The completed Alignment Protocol must then
be delivered to Half Moon Bay and physically inserted into the original
company's hardened coastal mainframe.

The Vision Jet is capable, but fuel is scarce. Large airports are often empty, while small and forgotten airfields may still hold valuable reserves. Every flight becomes a strategic decision involving distance, runway length, fuel availability and aircraft condition.

You must short-hop across the globe, manage your remaining fuel, choose your destinations carefully and keep your aircraft mechanically sound.

Humanity’s last chance is on board.
