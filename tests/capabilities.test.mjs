import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

const manifestPath = new URL("../kody-store.json", import.meta.url);
const capabilitiesDir = new URL("../capabilities/", import.meta.url);
const workflowsDir = new URL("../workflows/", import.meta.url);
const goalTemplatesDir = new URL("../goals/templates/", import.meta.url);

describe("Store capabilities", () => {
  const sharedEngineParts = {
    commands: new Set(["kody-live-probe"]),
    hooks: new Set(["block-git", "block-write", "kody-live-trace"]),
    skills: new Set(["kody-live-marker", "systematic-debugging"]),
  };

  it("declares capabilities as a first-class asset root", async () => {
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));

    assert.equal(manifest.assetRoots.capabilities, "capabilities");
  });

  it("declares workflows as a first-class asset root", async () => {
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));

    assert.equal(manifest.assetRoots.workflows, "workflows");
  });

  it("contains migrated capability folders with profile and capability body", async () => {
    assert.equal(existsSync(capabilitiesDir), true, "capabilities must exist");

    const entries = await readdir(capabilitiesDir, { withFileTypes: true });
    const slugs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);

    assert.ok(slugs.length > 0, "capability catalog must not be empty");
    for (const slug of slugs) {
      const dir = join(capabilitiesDir.pathname, slug);
      assert.equal(existsSync(join(dir, "profile.json")), true, `${slug} must include profile.json`);
      assert.equal(existsSync(join(dir, "capability.md")), true, `${slug} must include capability.md`);
    }
  });

  it("ships every subagent declared by a capability profile", async () => {
    const entries = await readdir(capabilitiesDir, { withFileTypes: true });
    const slugs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);

    for (const slug of slugs) {
      const dir = join(capabilitiesDir.pathname, slug);
      const profilePath = join(dir, "profile.json");
      const profile = JSON.parse(await readFile(profilePath, "utf8"));
      const subagents = profile.claudeCode?.subagents ?? [];

      for (const name of subagents) {
        const localAgent = join(dir, "agents", `${name}.md`);

        assert.equal(
          existsSync(localAgent),
          true,
          `${slug} declares missing subagent ${name}`,
        );
      }
    }
  });

  it("ships every declared plugin part or uses a known engine shared part", async () => {
    const entries = await readdir(capabilitiesDir, { withFileTypes: true });
    const slugs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);

    for (const slug of slugs) {
      const dir = join(capabilitiesDir.pathname, slug);
      const profilePath = join(dir, "profile.json");
      const profile = JSON.parse(await readFile(profilePath, "utf8"));
      const parts = [
        { bucket: "skills", names: profile.claudeCode?.skills ?? [], suffix: "", shared: sharedEngineParts.skills },
        { bucket: "commands", names: profile.claudeCode?.commands ?? [], suffix: ".md", shared: sharedEngineParts.commands },
        { bucket: "hooks", names: profile.claudeCode?.hooks ?? [], suffix: ".json", shared: sharedEngineParts.hooks },
      ];

      for (const part of parts) {
        for (const name of part.names) {
          const localPart = join(dir, part.bucket, `${name}${part.suffix}`);

          assert.equal(
            existsSync(localPart) || part.shared.has(name),
            true,
            `${slug} declares missing ${part.bucket} entry ${name}`,
          );
        }
      }
    }
  });

  it("exposes scout subagents mentioned by capability prompts", async () => {
    const entries = await readdir(capabilitiesDir, { withFileTypes: true });
    const slugs = entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);
    const scoutPattern = /`([a-z0-9-]+-scout)` subagents/g;

    for (const slug of slugs) {
      const dir = join(capabilitiesDir.pathname, slug);
      const promptPath = join(dir, "prompt.md");
      if (!existsSync(promptPath)) continue;

      const profilePath = join(dir, "profile.json");
      const profile = JSON.parse(await readFile(profilePath, "utf8"));
      const prompt = await readFile(promptPath, "utf8");
      const declared = new Set(profile.claudeCode?.subagents ?? []);
      const mentioned = [...prompt.matchAll(scoutPattern)].map((match) => match[1]);

      for (const name of mentioned) {
        assert.equal(declared.has(name), true, `${slug} prompt mentions ${name} but profile does not expose it`);
      }
    }
  });


  it("does not expose legacy action or removed capability roots", async () => {
    const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    const roots = manifest.assetRoots;
    const removedCapabilityRoot = ["agent", "respon", "sibilities"].join("-");
    const oldActionsRoot = ["agent", "actions"].join("-");

    assert.equal(roots[removedCapabilityRoot], undefined);
    assert.equal(roots[oldActionsRoot], undefined);
    assert.equal(roots.implementations, undefined);
    assert.equal(existsSync(new URL(`../${removedCapabilityRoot}/`, import.meta.url)), false);
    assert.equal(existsSync(new URL(`../${oldActionsRoot}/`, import.meta.url)), false);
    assert.equal(existsSync(new URL("../implementations/", import.meta.url)), false);
    assert.equal(existsSync(new URL("../.kody/", import.meta.url)), false);
  });

  it("ships web-release as an explicit ordered workflow", async () => {
    const workflowPath = join(workflowsDir.pathname, "web-release", "workflow.json");
    assert.equal(existsSync(workflowPath), true, "web-release workflow must exist");

    const workflow = JSON.parse(await readFile(workflowPath, "utf8"));
    const steps = workflow.steps ?? [];

    assert.equal(workflow.version, 1);
    assert.deepEqual(
      steps.map((step) => step.capability),
      ["release-prepare", "release-merge", "release-promote", "release-merge", "vercel-production-deploy"],
    );
    assert.equal(steps.filter((step) => step.capability === "release-merge").length, 2);
    assert.deepEqual(steps[0].cliArgs, { prefer: "ours" });
    assert.equal(steps[1].target, "pr");
    assert.equal(steps[3].target, "pr");
  });

  it("ships task-delivery as a workflow-target loop", async () => {
    const workflowPath = join(workflowsDir.pathname, "task-delivery", "workflow.json");
    const templatePath = join(goalTemplatesDir.pathname, "task-delivery", "state.json");
    assert.equal(existsSync(workflowPath), true, "task-delivery workflow must exist");
    assert.equal(existsSync(templatePath), true, "task-delivery loop template must exist");

    const workflow = JSON.parse(await readFile(workflowPath, "utf8"));
    const template = JSON.parse(await readFile(templatePath, "utf8"));
    const steps = workflow.steps ?? [];

    assert.equal(workflow.version, 1);
    assert.deepEqual(
      steps.map((step) => step.capability),
      ["task-verifier", "assigned-task-runner", "health-check", "task-leader"],
    );
    assert.deepEqual(template.loopTarget, { type: "workflow", id: "task-delivery" });
    assert.deepEqual(template.capabilities, []);
  });

  it("keeps task delivery dispatch and verification boundaries clean", async () => {
    const verifierProfilePath = new URL("../capabilities/task-verifier/profile.json", import.meta.url);
    const verifierSkillPath = new URL(
      "../capabilities/task-verifier/skills/verifier-method/SKILL.md",
      import.meta.url,
    );
    const runnerProfilePath = new URL("../capabilities/assigned-task-runner/profile.json", import.meta.url);
    const runnerBodyPath = new URL("../capabilities/assigned-task-runner/capability.md", import.meta.url);

    const verifierProfile = JSON.parse(await readFile(verifierProfilePath, "utf8"));
    const verifierSkill = await readFile(verifierSkillPath, "utf8");
    const runnerProfile = JSON.parse(await readFile(runnerProfilePath, "utf8"));
    const runnerBody = await readFile(runnerBodyPath, "utf8");

    assert.deepEqual(verifierProfile.inputs, []);
    assert.equal(
      verifierProfile.scripts.postflight.some((entry) => entry.script === "postAgentComment"),
      false,
    );
    assert.match(verifierSkill, /--add-assignee kody/);
    assert.equal(verifierSkill.includes('--add-label "status:verified'), false);

    assert.deepEqual(runnerProfile.capabilityTools, ["start_capability"]);
    assert.equal(runnerProfile.capabilityToolMode, "append");
    assert.equal(runnerProfile.claudeCode.enableSubmitTool, true);
    assert.ok(runnerProfile.claudeCode.tools.includes("mcp__kody-submit"));
    assert.match(runnerBody, /Do not post a bot-authored `@kody` comment/);
  });

  it("keeps daily web release loop pointing through goal then workflow", async () => {
    const templatePath = join(goalTemplatesDir.pathname, "daily-web-release-loop", "state.json");
    const template = JSON.parse(await readFile(templatePath, "utf8"));

    assert.deepEqual(template.loopTarget, { type: "goal", id: "web-release" });
    assert.equal(template.targetGoal.id, "web-release");
    assert.deepEqual(template.targetGoal.workflowRef, { source: "store", id: "web-release" });
    assert.deepEqual(template.targetGoal.chain, [
      "daily-web-release-loop",
      "web-release goal",
      "store workflow:web-release",
      "workflow capabilities",
    ]);
  });

  it("keeps PR health triage advisory-only", async () => {
    const profilePath = new URL("../capabilities/pr-health-triage/profile.json", import.meta.url);
    const skillPath = new URL(
      "../capabilities/pr-health-triage/skills/pr-health-triage/SKILL.md",
      import.meta.url,
    );
    const promptPath = new URL("../capabilities/pr-health-triage/prompt.md", import.meta.url);
    const profile = JSON.parse(await readFile(profilePath, "utf8"));
    const skill = await readFile(skillPath, "utf8");
    const prompt = await readFile(promptPath, "utf8");
    const advisoryTools = ["list_prs_to_repair", "read_ledger", "recommend_to_operator"];

    assert.deepEqual(profile.cliTools, []);
    assert.deepEqual(profile.claudeCode.tools, ["Read"]);
    assert.deepEqual(profile.capabilityTools, advisoryTools);
    assert.deepEqual(profile.tools, advisoryTools);
    assert.match(skill, /recommendations_posted/);
    assert.match(skill, /Do not write\s+`data\.recommendations`/);
    assert.match(skill, /kody-intent/);
    assert.doesNotMatch(skill, /kody-cmd/);
    assert.doesNotMatch(skill, /@kody/);
    assert.match(prompt, /\{\{capabilityReference\}\}/);
    assert.match(prompt, /\{\{jobStateJson\}\}/);
  });

  it("treats missing release PR checks as pending", async () => {
    const scriptPath = new URL("../capabilities/release-merge/release-merge.sh", import.meta.url);
    const script = await readFile(scriptPath, "utf8");

    assert.match(script, /no checks reported/);
    assert.match(script, /raw="\[\]"/);
  });

  it("lets release-merge wait longer than the default shell timeout", async () => {
    const profilePath = new URL("../capabilities/release-merge/profile.json", import.meta.url);
    const profile = JSON.parse(await readFile(profilePath, "utf8"));
    const shell = profile.scripts.preflight.find((step) => step.shell === "release-merge.sh");

    assert.equal(shell.timeoutSec, 2100);
  });

  it("uses merge commits for release promotion PRs", async () => {
    const scriptPath = new URL("../capabilities/release-merge/release-merge.sh", import.meta.url);
    const script = await readFile(scriptPath, "utf8");

    assert.match(script, /merge_args=\(--squash\)/);
    assert.match(script, /\$head_ref" == "\$default_branch"/);
    assert.match(script, /\$base_ref" == "\$release_branch"/);
    assert.match(script, /merge_args=\(--merge\)/);
  });

  it("does not gate release merges on wiki publish checks", async () => {
    const scriptPath = new URL("../capabilities/release-merge/release-merge.sh", import.meta.url);
    const script = await readFile(scriptPath, "utf8");

    assert.match(script, /Deploy Wiki to GitHub Pages/);
    assert.match(script, /Publish Complete/);
    assert.match(script, /close-publish-issue/);
  });

  it("creates release branches from the configured default branch", async () => {
    const scriptPath = new URL("../capabilities/release-prepare/prepare.sh", import.meta.url);
    const script = await readFile(scriptPath, "utf8");

    assert.match(script, /checkout_default_branch/);
    assert.match(script, /git checkout -f -B "\$default_branch" "origin\/\$\{default_branch\}"/);
  });

  it("pushes release branches with the engine-selected GitHub token", async () => {
    const scriptPath = new URL("../capabilities/release-prepare/prepare.sh", import.meta.url);
    const script = await readFile(scriptPath, "utf8");

    assert.match(script, /git_push\(\)/);
    assert.match(script, /x-access-token:%s/);
    assert.match(script, /http\.https:\/\/github\.com\/\.extraheader="/);
    assert.match(script, /http\.https:\/\/github\.com\/\.extraheader=AUTHORIZATION: basic/);
    assert.match(script, /git_push -u --force-with-lease origin "\$release_branch"/);
    assert.match(script, /git_push -u origin "\$release_branch"/);
  });
});
