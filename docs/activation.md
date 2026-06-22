# Activation

The store is a catalog, not an auto-run list. Consumer repos decide which shared company model is active from `kody.config.json`.

```json
{
  "company": {
    "activeGoals": ["prs-stay-mergeable", "product-quality"]
  }
}
```

## Objectives and Routines

Store goals are inactive objective or routine templates. Consumer repos activate the company model through `company.activeGoals`.

Routines own scheduled duty decisions. A duty may declare `every`, `agent`, and `executable`, but the routine tick decides whether that duty is due, skipped, blocked, or selected.

Default routine templates:

- `prs-stay-mergeable`
- `product-quality`
- `codebase-health`
- `release-safety`
- `kody-company-health`

Consumer repos may also define local goal templates.

```text
.kody/goals/templates/<slug>/state.json
.kody/goals/instances/<id>/state.json
```

String activation creates one stable runtime instance from a matching store/local template, or activates an existing instance by id.

```json
{ "company": { "activeGoals": ["prs-stay-mergeable"] } }
```

Scheduled activation creates a fresh runtime instance from a template each time bucket, persists it to the consumer repo's `kody-state` branch, then ticks that instance.

```json
{ "company": { "activeGoals": [{ "template": "release-safety", "every": "1w" }] } }
```

Supported intervals are `Nm`, `Nh`, `Nd`, and `Nw`, for example `15m`, `2h`, `1d`, and `1w`.

Store goals must not contain repo-specific runtime history. Runtime goal progress belongs in the consumer repo's `kody-state` branch.

## Duties

Store duties are available responsibilities or commands. They are no longer the main scheduled fan-out surface.

Rules:

- Scheduled company behavior should be activated through `company.activeGoals`.
- Duty cadence is reusable duty information; goal tick owns the scheduling decision.
- Manual duty runs still work from the dashboard or workflow dispatch.
- `company.activeDuties` is legacy compatibility; do not use it for new scheduled company behavior.
- Local repo duties remain repo-owned.
- Do not add `disabled: true` to all store duties.
- Activation belongs in the consumer repo, not the catalog item.

## Mental Model

```text
kody-store = menu
consumer repo = decides what is enabled
duty = available responsibility or command
objective/routine = operator promise that owns scheduled duty decisions
activation = permission to run
scheduled routine = template creates new runtime instance per bucket
```
