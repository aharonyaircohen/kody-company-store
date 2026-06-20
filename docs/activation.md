# Activation

The store is a catalog, not an auto-run list. Consumer repos decide which shared company model they activate from `kody.config.json`.

```json
{
  "company": {
    "activeDuties": ["release"],
    "activeGoals": ["web-release"]
  }
}
```

## Duties

A store duty is an available standing responsibility. A duty may declare `every`, `staff`, and `executable`, but those fields do not make it run in every repo. They are used only after the consumer lists the duty under `company.activeDuties`.

Rules:

- Missing `company.activeDuties` means no store duties auto-run.
- Empty `company.activeDuties` means no store duties auto-run.
- Local repo duties remain repo-owned.
- Do not add `disabled: true` to all store duties. Activation belongs to the consumer, not the catalog item.

## Goals

Store goals are inactive templates. Consumer repos may also define local goal templates.

```text
.kody/goals/templates/<slug>/state.json
.kody/goals/instances/<id>/state.json
```

String activation keeps the old behavior: it activates existing instances by id or by template.

```json
{ "company": { "activeGoals": ["web-release"] } }
```

Scheduled activation creates a fresh instance from the template for each time bucket, persists it to the consumer repo's `kody-state` branch, then ticks that instance.

```json
{
  "company": {
    "activeGoals": [
      { "template": "web-release", "every": "1w", "facts": { "issue": 123 } }
    ]
  }
}
```

Supported intervals are `Nm`, `Nh`, `Nd`, and `Nw`, such as `15m`, `2h`, `1d`, or `1w`.

Store goals must not contain repo-specific runtime history. Runtime goal progress belongs in the consumer repo's `kody-state` branch.

## Mental Model

```text
kody-store = menu
consumer repo = decides what is enabled
duty = available responsibility
goal = available outcome template
activation = permission to run
scheduled goal = template creates a new runtime instance per bucket
```
