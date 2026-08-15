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

## How it works

```
pmg setup info --json  ──poll (Timer)──▶  PmgService  ──▶  bar shield colour + panel layers
~/.config/safedep/pmg/logs/YYYYMMDD-pmg.log ──watch (FileView)──▶  feed, today counts, block overlay
```

`PmgService.qml` owns all state; `PmgModel.js` is the pure, framework-free logic
(event parsing, today counts, block detection) and is unit-tested with plain
Node — no Wayland session required:

```bash
node --test
```

The event log path follows PMG's daily rotation across midnight, and the overlay
only fires for blocks newer than what was already on disk when the shell
started, so history is never replayed.

## Testing it works

Real block (uses PMG's benign test package, flagged as malicious for testing):

```bash
npm install --no-cache --prefer-online safedep-test-pkg@0.1.3
```

The shield flashes red, the overlay appears, and the block lands in the feed.

To exercise the overlay without a package manager, append a synthetic event to
today's log:

```bash
LOG=~/.config/safedep/pmg/logs/$(date +%Y%m%d)-pmg.log
printf '{"timestamp":"%s","event_type":"malware_blocked","package_name":"pino-sdk-v2","version":"2.0.1","ecosystem":"npm","message":"Typosquat of pino; exfiltrates environment variables"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
```

### Plugin QA checklist

Per the Omarchy plugin testing guidance: click, <kbd>Esc</kbd>, shell open and
close, disable, re-enable, shell restart, removal — plus a theme switch (colours
should follow the active theme) and a real `malware_blocked` driving the overlay.

## Remove

```bash
omarchy plugin remove io.github.safedep.pmg
```

## License

Apache-2.0. See [LICENSE](LICENSE).
