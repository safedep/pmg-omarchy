# PMG for Omarchy

[![CI](https://github.com/safedep/pmg-omarchy/actions/workflows/ci.yml/badge.svg)](https://github.com/safedep/pmg-omarchy/actions/workflows/ci.yml)

A native [Omarchy](https://omarchy.org) (Quattro) bar plugin for
[PMG](https://github.com/safedep/pmg) — SafeDep's install-time package firewall.

One shield in the bar shows your supply-chain protection at a glance and turns
red the moment PMG blocks a malicious package. Click it for a panel with the
active protection layers, today's tally, and a live feed of what PMG allowed,
held, and blocked.

The plugin is pure presentation. It reads what PMG already exposes — `pmg setup
info --json` for health and layers, and PMG's JSONL event log for activity — and
contains no security logic of its own.

## Requirements

- Omarchy 4.x ("Quattro") with the Quickshell plugin system.
- [PMG](https://github.com/safedep/pmg) **0.26+** installed and on `PATH`, with
  shell integration set up:

  ```bash
  pmg setup install
  ```

  (The `--json` status surface this plugin polls landed in PMG 0.26.)

## Install

```bash
omarchy plugin add https://github.com/safedep/pmg-omarchy.git --enable
```

Move it to a different bar section if you like:

```bash
omarchy bar move io.github.safedep.pmg --section right
```

## Settings

Configure via Omarchy's plugin settings (`omarchy plugin` UI) or the bar config:

| Setting | Default | Meaning |
| --- | --- | --- |
| `refreshIntervalSec` | 30 | How often to poll `pmg setup info --json`. |
| `feedLimit` | 12 | Rows shown in the activity feed. |
| `showOverlay` | On | Show the fullscreen alert on a block. |
| `notifyOnBlock` | On | Send a desktop notification on a block. |

## Update

Plugins are not updated automatically. Pull the latest version manually:

```bash
omarchy plugin update io.github.safedep.pmg
```

Omarchy fetches the changes, re-validates the plugin, and reloads the shell (it
rolls back automatically if the new version fails validation).

## Remove

```bash
omarchy plugin remove io.github.safedep.pmg
```

## License

Apache-2.0. See [LICENSE](LICENSE).
