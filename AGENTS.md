# Codex Instructions

Before making coding or design decisions, read `project_brief.md`.

Before building each step of the app, also consult the relevant entries in
`Commands_Xplane12.txt` and `DataRefs_Xplane12.txt`. Use these local X-Plane 12
references to verify command and dataref names rather than relying on memory.

This project is an X-Plane 12 survival campaign implemented with FlyWithLua.

## Required principles

- Preserve the 2030 near-future story and aviation-survival tone.
- Use Lua and FlyWithLua unless explicitly instructed otherwise.
- Develop one small, testable feature at a time.
- Prioritise stability and readability over complexity.
- Treat X-Plane and airport data as potentially incomplete.
- Guard against nil values and invalid external data.
- Never allow missing airport data to crash a draw or update callback.
- Use descriptive function and variable names.
- Keep code modular and heavily commented.
- Do not add unrelated features without being asked.
- Do not rewrite working systems unnecessarily.
- Prefer complete replacement functions or complete tested script versions when changes are extensive.
- Preserve the Cirrus Vision Jet SF50 as the initial campaign aircraft.
- Preserve the runway-based variable airport fuel model: smaller airfields
  generally retain more fuel, while larger airports generally retain less.
  Keep balancing changes explicit and documented rather than reverting to a
  fixed allocation.
- The campaign exclusively supports the Cirrus Vision Jet SF50 and may rely on
  its two-tank fuel layout.
- Keep the interface professional, restrained and believable for 2030.
- Avoid arcade, fantasy, zombie or exaggerated military themes.

## Project reference

The complete narrative, gameplay objectives, implemented systems and planned direction are documented in `project_brief.md`.
