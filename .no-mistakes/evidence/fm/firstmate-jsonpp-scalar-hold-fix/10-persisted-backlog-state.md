=== persisted backlog state: escaped-body run, after the captain answered ===
(file: <fixture home>/data/backlog.md - the real markdown backend tasks-axi writes)

## In flight
- [ ] ishira-event-time-alignment - Align Project Ishira event-time windows (repo: ishira) (kind: scout) (since 2026-09-12)
## Queued
## Done
- [x] ishira-opus-nlu-audit - Audit Project Ishira Opus NLU review layer data/ishira-opus-nlu-audit/report.md (repo: ishira) (kind: scout) (reported 2026-09-12) (hold: captain must choose the review-layer hardening plan) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: a3dd4d8d05d7ad891cb5180de8ee5dbd1ea12d6a67c63f5e5275e569c9ed65fe
  Resolution mode: answered

  Captain decision:
  Harden the review layer: gate Opus NLU rollout on the "route" classifier audit.

  Audit finding: the "route" classifier drops a literal backslash \ mid-utterance.
  Second line after the encoded newline: latency budget is 120ms.

  Deliverable of the finished work: report data/ishira-opus-nlu-audit/report.md


=== persisted backlog state: empty-body sentinel run, after the captain answered ===

## In flight
- [ ] ishira-event-time-alignment - Align Project Ishira event-time windows (repo: ishira) (kind: scout) (since 2026-09-12)
## Queued
## Done
- [x] ishira-opus-nlu-audit - Audit Project Ishira Opus NLU review layer data/ishira-opus-nlu-audit/report.md (repo: ishira) (kind: scout) (reported 2026-09-12) (hold: captain must choose the review-layer hardening plan) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: a3dd4d8d05d7ad891cb5180de8ee5dbd1ea12d6a67c63f5e5275e569c9ed65fe
  Resolution mode: answered

  Captain decision:
  Harden the review layer: gate Opus NLU rollout on the "route" classifier audit.

  Deliverable of the finished work: report data/ishira-opus-nlu-audit/report.md


=== persisted backlog state: escaped title + hold reason run ===

## In flight
## Queued

## Done
- [x] ishira-opus-nlu-audit - Audit the "route" head \ and the Opus NLU review layer (repo: ishira) (kind: scout) (done 2026-09-12) (hold: captain must pick "harden now" \ or defer the Opus NLU review layer) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: d78d9906aece26410b97ecc2997708dd1615b115281ba90b159eb832f685bfab
  Resolution mode: answered

  Captain decision:
  Harden the "route" head now; the \ escape path ships behind the audit gate.

