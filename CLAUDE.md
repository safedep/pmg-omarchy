# pmg-omarchy

An Omarchy (Quattro) bar plugin that shows [PMG](https://github.com/safedep/pmg)
protection status. It is written in Quickshell QML. It only shows information. It
has no security logic.

## Writing rules for agents

- **Minimal code comments.** Do not comment obvious code. Add a comment only for
  a trade-off or non-obvious intent. Keep it to one or two short sentences.
- **Simplified Technical English (ASD-STE100) for humans.** Write comments and
  documentation (README, docs, commit messages) in simple technical English:
  short sentences, active voice, present tense, one idea per sentence, simple
  words.
- **No em dashes.** Do not use the em dash character in code, comments, strings,
  or docs. Use a period or a comma, or rewrite the sentence.
- Match the existing QML style. Follow the idioms of the Omarchy shell plugins.

## Layout

- `manifest.json`: plugin manifest and settings schema.
- `PmgWidget.qml`: the bar icon and the panel. Presentation only.
- `PmgService.qml`: the data engine. Owns all state.
- `BlockOverlay.qml`: the fullscreen alert for a blocked package.
- `PmgModel.js`: pure logic. No framework code. Tested with Node.
- `test/model.test.mjs`: tests for `PmgModel.js`.

## Data sources

- `pmg setup info --json`: protection health and layers (schema_version 1).
- `~/.config/safedep/pmg/logs/YYYYMMDD-pmg.log`: JSONL event log. Drives the
  feed, today's counts, and block alerts.

Put new logic that can be pure in `PmgModel.js` and test it. Keep the QML
declarative.

## Build and test

```bash
node --test                                              # model tests
qmllint -I "$OMARCHY_PATH/shell" *.qml                   # QML lint
bash scripts/validate.sh                                 # manifest and structure
omarchy plugin validate "$PWD"                           # manifest schema
```

Run all four before you commit. CI runs the model tests and the linters on every
pull request.
