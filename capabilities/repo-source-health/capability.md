# Repository source health

Runs the consumer repository's configured `quality` commands on the current
default-branch commit and publishes `Kody Source Health` as a GitHub commit
status. A terminal status is reused for the same commit, so checks run once per
source change.

This is an Observe capability. It reports source health but does not create an
issue, change source, or dispatch a repair.
