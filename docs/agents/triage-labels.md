# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## Labels in this repository

All five labels exist on `planningktl-creator/thip-kpi-bms` with these descriptions:

| Label              | Description                                     |
| ------------------ | ----------------------------------------------- |
| `needs-triage`     | Maintainer needs to evaluate this issue         |
| `needs-info`       | Waiting on reporter for more information        |
| `ready-for-agent`  | Fully specified, ready for an AFK agent         |
| `ready-for-human`  | Requires human implementation                   |
| `wontfix`          | Will not be actioned                            |

The vocabulary is the default: label strings match the canonical role names, so no mapping ambiguity exists.

## Wayfinder labels

`/wayfinder` uses a separate label family for its map and child tickets (see `docs/agents/issue-tracker.md`, "Wayfinding operations"):

| Label                | Used by                          |
| -------------------- | -------------------------------- |
| `wayfinder:map`      | the map issue                    |
| `wayfinder:research` | research decision ticket         |
| `wayfinder:prototype`| prototype decision ticket        |
| `wayfinder:grilling` | grilling decision ticket         |
| `wayfinder:task`     | task decision ticket             |
