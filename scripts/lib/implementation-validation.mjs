import { createHash } from "node:crypto";

function canonical(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonical).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

export function capabilityRevision(capability) {
  return createHash("sha256").update(canonical(capability)).digest("hex");
}

function list(value) {
  return Array.isArray(value) ? value : [];
}

function hasAgentExecutionAssets(record) {
  const claudeCode = record.runtime?.claudeCode ?? {};
  return (
    record.files.includes("prompt.md") ||
    list(claudeCode.skills).length > 0 ||
    list(claudeCode.tools).length > 0 ||
    list(claudeCode.commands).length > 0 ||
    list(claudeCode.subagents).length > 0 ||
    list(claudeCode.plugins).length > 0 ||
    list(claudeCode.mcpServers).length > 0 ||
    list(record.runtime?.tools).length > 0 ||
    list(record.runtime?.capabilityTools).length > 0
  );
}

export function validateImplementationCatalog({
  capabilities,
  implementations,
}) {
  const errors = [];
  const ids = new Set();

  for (const record of implementations) {
    const { id, definition, runtime, files } = record;
    if (ids.has(id)) {
      errors.push(`Implementation "${id}" is duplicated.`);
    }
    ids.add(id);

    if (definition.id !== id) {
      errors.push(
        `Implementation directory "${id}" contains definition id "${definition.id}".`,
      );
    }

    const capabilityId = definition.capabilityRef?.id;
    const capability = capabilities.get(capabilityId);
    if (!capability) {
      errors.push(
        `Implementation "${id}" references missing Capability "${capabilityId}".`,
      );
    } else if (
      definition.compatibleCapabilityRevision !==
      capabilityRevision(capability)
    ) {
      errors.push(
        `Implementation "${id}" compatibleCapabilityRevision is stale for Capability "${capabilityId}".`,
      );
    }

    if (!runtime) {
      errors.push(`Implementation "${id}" is missing runtime.json.`);
      continue;
    }

    if (definition.type === "agent") {
      if (definition.agentRef?.kind !== "agent" || !definition.agentRef.id) {
        errors.push(`Agent Implementation "${id}" must define agentRef.`);
      }
      if (!hasAgentExecutionAssets(record)) {
        errors.push(
          `Agent Implementation "${id}" has no prompt, Skill, or agent tool.`,
        );
      }
      continue;
    }

    if (definition.type === "script") {
      if (definition.agentRef !== undefined) {
        errors.push(
          `Script Implementation "${id}" must not define agentRef.`,
        );
      }
      if (files.includes("prompt.md")) {
        errors.push(
          `Script Implementation "${id}" must not contain prompt.md.`,
        );
      }
      continue;
    }

    errors.push(
      `Implementation "${id}" has unsupported type "${definition.type}".`,
    );
  }

  return errors;
}
