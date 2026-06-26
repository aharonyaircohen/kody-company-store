#!/usr/bin/env bash
set -euo pipefail

node <<'NODE'
const fs = require('fs')
const path = require('path')
const cp = require('child_process')

const root = process.cwd()
const agentResponsibilitiesDir = path.join(root, '.kody', 'agent-responsibilities')
const memoryDir = path.join(root, '.kody', 'memory')
const reportFile = 'reports/job-gap-scan.md'
const dryRun = process.env.KODY_DRY_RUN === '1' || process.env.JOB_GAP_SCAN_DRY_RUN === '1'
const noCommit = process.env.KODY_NO_COMMIT === '1' || process.env.JOB_GAP_SCAN_NO_COMMIT === '1'

const catalogue = [
  {
    slug: 'sentry-digest',
    title: 'Sentry top-errors digest',
    headline: 'Daily digest loudest unresolved Sentry errors so production noise becomes triage list, not chase.',
    why: 'repo already ships Sentry. Errors visible only in Sentry UI invisible kody - turning issues closes loop.',
    risk: 'low',
    effort: 'low',
    value: 'high',
    roi: 95,
    markdown: '---\nevery: 24h\nagent: kody\n---\n# sentry-digest\n\n## Job\n\nOnce day, fetch 10 unresolved Sentry errors ranked by `events x users_affected` open one GitHub issue per recurring error no open tracking issue yet.\n\n## Tick procedure REQUIRED\n\nFully scripted. Add `.kody/agent-actions/sentry-digest/tick.sh` before enabling it.\n',
  },
  {
    slug: 'secret-leak-scan',
    title: 'Secret-leak scan',
    headline: 'Schedule gitleaks daily open one tracking issue on any finding - cheap defensive layer.',
    why: 'Once secret is in git history, removal is expensive - early detection only affordable insurance.',
    risk: 'low',
    effort: 'low',
    value: 'high',
    roi: 85,
    markdown: '---\nevery: 24h\nagent: kody\n---\n# secret-leak-scan\n\n## Job\n\nRun `gitleaks detect` daily against full history. Open one issue per finding type, offending file+line redacted.\n',
  },
  {
    slug: 'stale-pr-janitor',
    title: 'Stale-PR janitor',
    headline: 'Nudge stale PRs and close abandoned ones so review queues stay clean.',
    why: "PRs left dangling rot review etiquette; explicit timeout makes it bot's job, not human's.",
    risk: 'low',
    effort: 'low',
    value: 'medium',
    roi: 80,
    markdown: '---\nevery: 24h\nagent: kody\n---\n# stale-pr-janitor\n\n## Job\n\nComment single nudge on PRs idle >14 days; close (with comment) 30 days. Skip drafts any PR carrying `kody:*` lifecycle label.\n',
  },
  {
    slug: 'issue-auto-triage',
    title: 'Issue auto-triage',
    headline: 'Label new issues content (`type:bug/feat/docs`, `area:*`) so inbox sorted without operator effort.',
    why: 'Triage today manual or absent - most projects pay tax forever; one agentResponsibility zeroes it out.',
    risk: 'low',
    effort: 'low',
    value: 'medium',
    roi: 78,
    markdown: '---\non:\n  issues:\n    types: [opened]\nagent: kody\n---\n# issue-auto-triage\n\n## Job\n\nWhen new issue opened, infer labels title+body apply them. Never close assign - labels only.\n',
  },
  {
    slug: 'bundle-size-diff',
    title: 'Bundle-size diff',
    headline: 'Comment per-PR on first-load JS delta; fail PR if regression >5%.',
    why: 'A Next.js bundle quietly grows by KBs per commit. Visibility on PRs only reliable defence.',
    risk: 'low',
    effort: 'medium',
    value: 'medium',
    roi: 70,
    markdown: '---\non:\n  pull_request:\n    types: [opened, synchronize]\nagent: kody\n---\n# bundle-size-diff\n\n## Job\n\nMeasure first-load JS before/after PR and comment delta. Flag regression >5%.\n',
  },
]

function log(message) {
  console.error(`[job-gap-scan] ${message}`)
}

function emitNextState(state, cursor) {
  console.log('```kody-job-next-state')
  console.log(JSON.stringify({ cursor, data: state, done: false }, null, 2))
  console.log('```')
}

function loadState() {
  try {
    return JSON.parse(process.env.KODY_JOB_STATE_JSON || '{}').data || {}
  } catch {
    return {}
  }
}

function gh(args) {
  const result = cp.spawnSync('gh', args, { encoding: 'utf8' })
  if (result.status !== 0) {
    throw new Error((result.stderr || result.stdout || `gh ${args.join(' ')} failed`).trim())
  }
  return result.stdout
}

function stateRepoTarget() {
  const consumerRepo = gh(['repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner']).trim()
  const [owner, repoName] = consumerRepo.split('/')
  let config = {}
  try {
    config = JSON.parse(fs.readFileSync(path.join(root, 'kody.config.json'), 'utf8'))
  } catch {}
  const stateRepo = config.state?.repo || config.stateRepo || `${owner}/kody-state`
  const rawPath = config.state?.path || config.statePath || repoName
  const statePath = String(rawPath || '').replace(/^\/+|\/+$/g, '')
  return {
    repo: stateRepo,
    path: `${statePath ? `${statePath}/` : ''}${reportFile}`,
  }
}

function readVerdicts() {
  const out = {}
  if (!fs.existsSync(memoryDir)) return out
  for (const name of fs.readdirSync(memoryDir)) {
    const match = /^verdict-ceo-proposal-([a-z0-9-]+)\.md$/.exec(name)
    if (!match) continue
    const slug = match[1]
    const text = fs.readFileSync(path.join(memoryDir, name), 'utf8')
    const fm = /^---\s*\n([\s\S]*?)\n---\s*$/m.exec(text)
    const meta = {}
    if (fm) {
      for (const line of fm[1].split(/\r?\n/)) {
        const idx = line.indexOf(':')
        if (idx >= 0) meta[line.slice(0, idx).trim()] = line.slice(idx + 1).trim()
      }
    }
    const source = meta.source || ''
    const decision = source.includes(':') ? source.split(':').pop() : ''
    if (!out[slug] || String(meta.recorded_at || '') > String(out[slug].recorded_at || '')) {
      out[slug] = { decision, recorded_at: meta.recorded_at || '' }
    }
  }
  return out
}

function existingAgentResponsibilitySlugs() {
  if (!fs.existsSync(agentResponsibilitiesDir)) return new Set()
  const slugs = new Set()
  for (const name of fs.readdirSync(agentResponsibilitiesDir)) {
    const full = path.join(agentResponsibilitiesDir, name)
    if (fs.statSync(full).isDirectory()) slugs.add(name)
    if (name.endsWith('.md')) slugs.add(name.replace(/\.md$/, ''))
  }
  return slugs
}

function renderCurrent(c) {
  return `## Current proposal\n\n**${c.slug}** - ${c.headline}\n\n### Why now\n\n${c.why}\n\n### Scoring\n\n| # | Item | Risk | Effort | Value | ROI |\n|---|------|------|--------|-------|-----|\n| 1 | ${c.title} | ${c.risk} | ${c.effort} | ${c.value} | ${c.roi} |\n\n### Draft agentResponsibility markdown\n\nIf approved, operator (or executor) would commit following \`.kody/agent-responsibilities/${c.slug}.md\`. This starting point, not final spec.\n\n\`\`\`\`markdown\n${c.markdown}\`\`\`\`\n\n### Verdict path\n\nApprove -> create agentResponsibility markdown above. Reject -> permanent - CEO will not surface slug again. Dismiss -> cooling-off 30 days, then eligible re-surface if signal grows.\n`
}

function renderCaughtUp() {
  return '## Current proposal\n\nAll caught up - no eligible new agentResponsibility proposal this cycle.\n'
}

function renderHistory(state, verdicts) {
  const rows = []
  const bySlug = Object.fromEntries(catalogue.map(c => [c.slug, c]))
  for (const slug of Object.keys(state.proposed || {}).sort()) {
    const title = bySlug[slug]?.title || slug
    const first = String(state.proposed[slug].firstSuggestedISO || '').slice(0, 10) || '-'
    const status = verdicts[slug]?.decision || 'pending'
    rows.push(`| ${slug} | ${title} | ${first} | ${status} |`)
  }
  return `## History\n\n| Slug | Title | First suggested | Status |\n|------|-------|-----------------|--------|\n${rows.join('\n')}\n`
}

function normalizedReport(text) {
  return text.replace(/^_Last updated:.*$/gm, '').trim()
}

function readRemoteReport(target) {
  try {
    const json = JSON.parse(gh(['api', `/repos/${target.repo}/contents/${target.path}`]))
    return {
      sha: json.sha || '',
      text: Buffer.from(String(json.content || '').replace(/\n/g, ''), 'base64').toString('utf8'),
    }
  } catch {
    return { sha: '', text: '' }
  }
}

function reportUnchanged(report, target) {
  return normalizedReport(readRemoteReport(target).text) === normalizedReport(report)
}

function writeRemoteReport(report, target) {
  const remote = readRemoteReport(target)
  const args = [
    'api',
    '-X',
    'PUT',
    `/repos/${target.repo}/contents/${target.path}`,
    '-f',
    'message=chore(reports): refresh job-gap-scan',
    '-f',
    `content=${Buffer.from(report, 'utf8').toString('base64')}`,
  ]
  if (remote.sha) args.push('-f', `sha=${remote.sha}`)
  gh(args)
}

const state = loadState()
state.proposed ||= {}
const verdicts = readVerdicts()
const existing = existingAgentResponsibilitySlugs()
const now = new Date()
const eligible = []

for (const candidate of catalogue) {
  if (existing.has(candidate.slug)) {
    log(`skip ${candidate.slug}: already in .kody/agent-responsibilities/`)
    continue
  }
  const verdict = verdicts[candidate.slug]
  if (verdict?.decision === 'reject') {
    log(`skip ${candidate.slug}: rejected (permanent)`)
    continue
  }
  if (verdict?.decision === 'dismiss' && verdict.recorded_at) {
    const ageMs = now - new Date(verdict.recorded_at)
    if (Number.isFinite(ageMs) && ageMs < 30 * 24 * 60 * 60 * 1000) {
      log(`skip ${candidate.slug}: dismissed within cooling-off window`)
      continue
    }
  }
  eligible.push(candidate)
}

eligible.sort((a, b) => b.roi - a.roi)
const chosen = eligible[0] || null
let proposalAlreadyRecorded = false
if (chosen) {
  log(`chose ${chosen.slug} (roi=${chosen.roi})`)
  const existingMeta = state.proposed[chosen.slug] || {}
  proposalAlreadyRecorded = Boolean(existingMeta.firstSuggestedISO)
  state.proposed[chosen.slug] = {
    firstSuggestedISO: existingMeta.firstSuggestedISO || now.toISOString(),
    lastWrittenISO: now.toISOString(),
  }
} else {
  log('no eligible proposals')
}

const report = `# Job Gap Scan\n\n_Cadence: daily - one proposed agentResponsibility per cycle, advisory only._\n\n_Last updated: ${now.toISOString()}_\n\n${chosen ? renderCurrent(chosen) : renderCaughtUp()}\n${renderHistory(state, verdicts)}`

if (dryRun) {
  log('dry run complete (skipped report write)')
  console.log(report)
  emitNextState(state, chosen?.slug || 'caught-up')
  process.exit(0)
}

const target = stateRepoTarget()
if (proposalAlreadyRecorded && reportUnchanged(report, target)) {
  log('tick complete: no substantive change (skipped report write)')
  emitNextState(state, chosen?.slug || 'caught-up')
  process.exit(0)
}

state.lastRunISO = now.toISOString()
if (noCommit) {
  log('tick complete (state repo report write suppressed)')
  emitNextState(state, chosen?.slug || 'caught-up')
  process.exit(0)
}
writeRemoteReport(report, target)
log(`tick complete: report written to ${target.repo}/${target.path}`)
emitNextState(state, chosen?.slug || 'caught-up')
NODE
