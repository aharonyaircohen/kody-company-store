# GitHub CMS State Example

This is a schema-first CMS config for a GitHub-backed collection.

The adapter creates the content path on first write. No installer step is
required; creating `articles/intro` writes:

```text
GitHub-CMS/content/articles/intro.json
```

in the resolved state repo on the `kody-state` branch.
