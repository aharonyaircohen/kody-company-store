# Activation

The store is a catalog. It is not an auto-run list.

Consumer repos decide which shared company model they activate. Store duties and
goals are inactive by default until the consumer opts in from `kody.config.json`.

```json
{
  "company": {
    "activeDuties": ["release"],
    "activeGoals": ["web-release"]
  }
}
```

## Duties

A store duty is an available standing responsibility.

The duty may declare `every`, `staff`, and `executable`, but those fields do not
make it run in every repo. They are used only after the consumer lists the duty
under `company.activeDuties`.

Rules:

- Missing `company.activeDuties` means no store duties auto-run.
- Empty `company.activeDuties` means no store duties auto-run.
- Local repo duties remain repo-owned and can run from the local repo.
- Do not add `disabled: true` to all store duties. Activation belongs to the
  consumer, not the catalog item.

## Goals

A store goal is an available managed-goal template.

Store goal templates live under `.kody/goals/templates/<slug>/state.json` and should use `state: "inactive"`. A consumer activates a goal
by listing it under `company.activeGoals`, then creates or updates the runtime
goal instance with repo facts such as `facts.issue`.

Rules:

- Missing `company.activeGoals` means no store goals auto-run.
- Empty `company.activeGoals` means no store goals auto-run.
- Store goals must not contain repo-specific runtime history.
- Runtime goal progress belongs to the consumer repo and `kody-state`.

## Mental Model

```text
kody-store = menu
consumer repo = decides what is enabled
duty = available responsibility
goal = available outcome template
activation = permission to run
```
