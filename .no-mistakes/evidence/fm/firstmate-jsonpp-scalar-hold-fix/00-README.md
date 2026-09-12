# Live validation: Firstmate captain-hold scalar-decode compatibility fix

Host that reproduces the blocker natively: **perl 5.16.3 / JSON::PP 2.27202 / tasks-axi 0.2.5**.
On this JSON::PP, `decode_json` on a top-level scalar dies with
`JSON text must be an object or array (... use allow_nonref to allow this)`.

`tasks-axi show --full` quotes a scalar field as a JSON string whenever it needs escaping.
A captain hold writes `Captain hold set: <ts>` into the body, and the `: ` alone is enough
to trigger quoting - so every captain-held row on this host hit the failing decode.

## What was driven

The real operator lifecycle for the completed Project Ishira Opus NLU audit, against the
real `tasks-axi` markdown backend in an isolated fixture home:

```
tasks-axi add + start
  -> bin/fm-captain-hold.sh hold      (the review-layer hardening question)
  -> bin/fm-captain-hold.sh complete  (completion gate)
  -> bin/fm-teardown.sh               (cleanup; retains the captain call, records the deliverable)
  -> bin/fm-captain-hold.sh answer    (registers the decision, closes the call)
```

A second task, `ishira-event-time-alignment`, stayed in flight throughout to confirm the
parallel Project Ishira event-time work is untouched.

## Per-commit result (same driver, three code roots)

| Code root | Result |
|---|---|
| `a27646c` (base, pre-fix) | **blocked at `hold`** - `could not decode the existing body` (`01-...`) |
| `06aaea4` (first fix only) | hold succeeds; **blocked at cleanup** - `its captain-held backlog item could not be returned to Queued atomically (could not decode the task body ...)` (`02-...`) |
| `f0c026d` (target) | **full lifecycle completes**: decision registered, synthesis report recorded as the deliverable (`03-...`) |

`06aaea4` is the exact sibling failure the round-1 review predicted in `fm_backlog_retain`,
reproduced live and then repaired by the shared decoder in `acd1102`.

## Adversarial scenarios

- `04-...` / `10-...`: a body carrying `"route"`, a literal `\`, and an embedded newline
  round-trips byte-exact through hold -> retain -> answer. The persisted backlog shows real
  double quotes, one backslash, and a real line break - no double-escaping, no literal `\n`.
- `05-...`: an empty body (the `-` / `""` sentinel boundary) leaves no stray `-` in the retained body.
- `06-...`: title and hold reason both carrying escapes, read back through `open --identity`,
  `diverged`, and the Bearings board. Same scenario is blocked on base (`07-...`).

## Falsifiability of the new regression assertion

`09-...` runs the repo's `test_captain_hold_mutations_address_the_beads_backend` against two
mutated copies of the shared decoder:

- mutant A re-escapes newlines -> test fails
- mutant B leaves embedded quotes escaped -> test fails **on the new assertion itself**,
  printing the expected/actual bodies

So the strengthened multiline assertion detects the corruption it names.

## Note on visual evidence

This change has no UI, HTML, or rendered surface - it is shell/perl decoding behind two CLI
entrypoints. The reviewer-visible artifacts are therefore CLI transcripts plus the persisted
`data/backlog.md` state the product actually wrote.

## Files

| File | What it shows |
|---|---|
| `01-base-a27646c-hold-blocked.log` | pre-fix: the hold itself refuses |
| `02-mid-06aaea4-retain-blocked.log` | sibling retain-path failure reproduced |
| `03-target-f0c026d-full-lifecycle.log` | fixed: end-to-end lifecycle completes |
| `04-target-escaped-body-roundtrip.log` | escapes + newline round-trip |
| `05-target-empty-body-sentinel.log` | empty-body sentinel boundary |
| `06-target-escaped-fields-read-surfaces.log` | escaped title/reason across read surfaces |
| `07-base-escaped-fields-blocked.log` | same scenario blocked pre-fix |
| `08-targeted-repo-suite.log` | the three touched repo regression cases |
| `09-regression-falsifiability-mutants.log` | mutation check of the new assertion |
| `10-persisted-backlog-state.md` | the real `data/backlog.md` the product wrote |
| `driver-*.sh` | the drivers, so a reviewer can re-run either scenario |
