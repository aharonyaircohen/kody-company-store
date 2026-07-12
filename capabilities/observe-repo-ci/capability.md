# Observe repository CI

Reads the latest default-branch GitHub Actions result and writes a durable
Observation. It updates one Finding for `repo-ci:main` while CI is unhealthy
and resolves that same Finding when CI becomes healthy.
