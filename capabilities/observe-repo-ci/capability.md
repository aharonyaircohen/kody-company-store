# Observe repository CI

Reads the latest default-branch GitHub Actions result and writes a durable
Observation and returns neutral evidence. Its owning Workflow publishes a
Finding Report while CI is unhealthy and a recovery run when CI becomes healthy.
