# X2030 physical-impact module investigation

**Status:** Physical impact removed after the reduced test reproduced the fault
**Recorded:** 29 July 2026

## Summary

On a Windows X-Plane 12 installation using three monitors, the centre monitor
stopped passing mouse clicks to SF50 cockpit manipulators whenever
`X2030_Impact.lua` was present in FlyWithLua's `Scripts` directory. Cockpit
switches on the two side monitors remained interactive, and X-Plane's menus on
the centre monitor also remained interactive.

The following simulator tests isolated the behaviour:

| Active X2030 files | Centre-monitor cockpit clicks |
| --- | --- |
| Neither script | Working |
| `X2030.lua` and `X2030_Impact.lua` | Not working |
| `X2030_Impact.lua` only | Not working |
| `X2030.lua` only | Working |
| `X2030.lua` and `X2030_Downward_Impact.lua` | Not working |

Renaming the high-resolution `images/Manapouri.png` asset and closing the
visible mission-computer window did not restore the centre-monitor cockpit
clicks. The image and mission-computer window are therefore not required to
reproduce this fault.

The supplied X-Plane log reported that both Lua files loaded successfully. It
did not contain an `[X2030 IMPACT]` event, an X2030 satellite-damage event, or a
Lua quarantine failure. This indicates that the problem occurs when the impact
module is initialised, not because an impact is deliberately fired at startup.

The later downward-only variant removed all lateral-force and moment bindings,
but centre-monitor cockpit clicks still failed. Removing that variant restored
the clicks. This narrows the reproducer to a helper whose only writable physics
integration is `sim/flightmodel/forces/fnrml_plug_acf`; changing the direction
or simplifying the impulse did not resolve the input conflict.

## Current technical finding

`X2030_Impact.lua` has no mouse callback, ImGui window, joystick override, or
automatic call to `X2030Impact.start()`. Its significant startup integrations
are six writable X-Plane plugin-force and plugin-moment datarefs:

```text
sim/flightmodel/forces/fside_plug_acf
sim/flightmodel/forces/fnrml_plug_acf
sim/flightmodel/forces/faxil_plug_acf
sim/flightmodel/forces/L_plug_acf
sim/flightmodel/forces/M_plug_acf
sim/flightmodel/forces/N_plug_acf
```

The module also binds read-only on-ground, simulation-time, and paused-state
datarefs. Because the problem was reproduced with `X2030_Impact.lua` alone,
the writable force/moment bindings are the leading suspects. A conflict with
FlyWithLua, a force-feedback integration, vJoy, another plugin using the same
accumulators, or X-Plane's multi-monitor input handling has not yet been
distinguished. Do not assume that the X-Plane dataref names themselves are
invalid; they are present and writable in the project's X-Plane 12 reference.

## Implemented resolution

Do not distribute or install `X2030_Impact.lua` or
`X2030_Downward_Impact.lua`. Run the campaign with `X2030.lua` only. This
preserves campaign progression, the mission computer, satellite surveillance,
audio handling, and satellite electrical-bus/engine-fire damage while omitting
only the supplementary physical force impulse.

The campaign no longer loads either helper, registers its per-frame update, or
offers the physics-only test button. The full-hit test and normal satellite hit
continue to apply impact audio, electrical-bus failures and the engine fire.
The two unsafe helper files have been removed from the project so they cannot be
accidentally copied into FlyWithLua's automatically scanned `Scripts` folder.

## Historical test plan

Use temporary diagnostic variants of the impact module and change only one
dataref group at a time. After every test, fully restart X-Plane rather than
relying only on closing a window or reloading a flight.

1. **Baseline:** Run `X2030.lua` without the impact helper and reconfirm centre,
   left, and right monitor cockpit interaction.
2. **Read-only module:** Retain only the on-ground, simulation-time, and pause
   bindings. Make `start()` return `false` and do not bind or write any plugin
   forces. Test cockpit interaction.
3. **Linear-force group:** Add the side, normal, and axial force bindings. Test
   before adding any moment bindings or firing an impulse.
4. **Moment group:** In a separate variant, add only roll, pitch, and yaw moment
   bindings. Test before firing an impulse.
5. **Individual binding isolation:** If a group reproduces the problem, add its
   datarefs one at a time to identify the precise trigger.
6. **Hardware/plugin matrix:** Repeat the smallest reproducing case with the
   MOZA force-feedback integration, vJoy, and other flight-model plugins
   disabled one at a time.
7. **Display matrix:** Test one monitor and then the original three-monitor
   arrangement using the same aircraft and X-Plane graphics configuration.
8. **Impulse test:** Only after cockpit interaction remains reliable should the
   guarded 0.24-second impulse be fired while airborne above the required test
   altitude.
9. **Packaging:** Before restoring the module to releases, avoid presenting a
   helper module as an independently scanned FlyWithLua script as well as
   loading it with `dofile`. Use a packaging approach confirmed to work with
   the installed FlyWithLua version.

For every diagnostic run, retain `Log.txt` and search for:

```text
[X2030 IMPACT]
[X2030 SATELLITE]
FlyWithLua Error
quarantine
```

Record the active monitors, force-feedback software, vJoy state, other active
plugins, and exact files in FlyWithLua's `Scripts` directory with each result.

## Criteria for re-enabling physical impacts

Do not restore either impact helper to the normal installation instructions until
all of the following are true:

- centre-monitor SF50 cockpit manipulators remain interactive after startup;
- interaction remains correct after a FlyWithLua reload;
- the result is repeatable with the three-monitor configuration;
- any replacement motion effect occurs only after an automatic hit or guarded test;
- no force or moment remains active after its short pulse;
- the campaign continues safely when the helper is absent; and
- FlyWithLua reports no script quarantine or runtime error.
