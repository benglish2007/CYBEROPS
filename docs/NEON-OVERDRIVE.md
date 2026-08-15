# Neon Overdrive UI Experiment

This branch isolates a heavier cyberpunk presentation from stable `main`.
Operational commands, privilege boundaries, safety checks, and recovery paths
remain unchanged.

## Theme selection

The lab defaults to:

```text
CYBEROPS_THEME=neon-overdrive
```

Set `CYBEROPS_THEME=classic` to compare against the v2.13 presentation. Both
themes preserve `NO_COLOR`, `--no-color`, narrow-terminal, and explicit text
status behavior.

## Visual language

- Cyan identifies operator-facing commands and live data.
- Magenta frames the control lattice and navigation.
- Acid green marks active or acknowledged state.
- Red is reserved for faults and destructive boundaries.
- Yellow and orange identify privilege or caution states.
- Purple identifies build, protocol, and system metadata.

The experiment favors rail-style menus, dense status framing, and consistent
command-deck vocabulary without obscuring the underlying operation names.
