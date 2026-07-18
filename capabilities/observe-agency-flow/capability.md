# Observe agency flow

Watches the agency's own pipeline instead of the product: open agent review
PRs on the state repo that have sat unreviewed, open capability request
issues nobody answered, and tracked Findings whose repair shows no recent
activity. Writes a durable Observation and returns neutral evidence. Its
owning Workflow publishes a Finding Report while the pipeline has stale
items and a recovery run when the pipeline is clear, so the operating and
evolution loops can repair the agency's own gaps.
