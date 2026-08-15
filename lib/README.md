# CYBEROPS Module Contracts

Files under `lib/` are sourced by `cyberops.sh`; they are not standalone
commands. The launcher resolves modules relative to its own filesystem location,
so CYBEROPS does not depend on the caller's current working directory.

Each module must:

- Produce no output merely because it was sourced.
- Avoid installing traps or changing shell options during load.
- Document public function inputs, outputs, return statuses, and side effects.
- Use shared runtime state only when the state is declared in `runtime.sh`.
- Keep state-changing operations behind the existing confirmation and dry-run
  helpers.
- Be safe to source repeatedly in isolated tests.

The launcher must fail before presenting a menu or changing system state when a
required module cannot be read.

## Loading order

1. `runtime.sh` initializes the version, theme, configuration defaults, and
   shared operation state.
2. `core.sh` and `ui.sh` provide shared validation, operation, and terminal
   helpers.
3. `diagnostics.sh` provides privacy-filtered support bundle generation.
4. `docker.sh`, `admin.sh`, `info.sh`, `vpn.sh`, `security.sh`,
   `quickhacks.sh`, and `usb.sh` provide focused feature modules.
5. `menu.sh` loads last and dispatches the feature menus.

Dependencies between feature modules should be avoided. Shared behavior belongs
in a focused common module instead.
