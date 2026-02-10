#!/usr/bin/env node
/**
 * Declarative skill installer — bypasses the skills CLI to call the JS API
 * directly, supporting both symlink and copy install modes.
 *
 * Usage:
 *   install.mjs <manifest.json>
 *
 * Manifest format:
 * {
 *   "mode": "symlink" | "copy",
 *   "stateFile": "/path/to/managed.json",
 *   "autoUpdate": true,
 *   "skills": [
 *     {
 *       "source": "owner/repo",
 *       "agents": ["opencode", "claude-code"],
 *       "skill": ["specific-skill"],
 *       "global": true,
 *       "fullDepth": false
 *     }
 *   ]
 * }
 */

import { execSync } from 'child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync,
         cpSync, symlinkSync, lstatSync, readlinkSync, rmSync, statSync } from 'fs';
import { join, basename, dirname, relative, resolve } from 'path';
import { homedir } from 'os';

const home = homedir();
const configHome = process.env.XDG_CONFIG_HOME || join(home, '.config');

// ── Agent directory mappings (from skills CLI source) ──────────────────
const AGENT_GLOBAL_DIRS = {
  'opencode':       join(configHome, 'opencode/skills'),
  'claude-code':    join(process.env.CLAUDE_CONFIG_DIR || join(home, '.claude'), 'skills'),
  'cursor':         join(home, '.cursor/skills'),
  'codex':          join(process.env.CODEX_HOME || join(home, '.codex'), 'skills'),
  'gemini-cli':     join(home, '.gemini/skills'),
  'github-copilot': join(home, '.copilot/skills'),
  'amp':            join(configHome, 'agents/skills'),
  'antigravity':    join(home, '.gemini/antigravity/skills'),
  'cline':          join(home, '.cline/skills'),
  'goose':          join(configHome, 'goose/skills'),
  'roo':            join(home, '.roo/skills'),
  'windsurf':       join(home, '.codeium/windsurf/skills'),
  'trae':           join(home, '.trae/skills'),
  'kilo':           join(home, '.kilocode/skills'),
  'kiro-cli':       join(home, '.kiro/skills'),
  'droid':          join(home, '.factory/skills'),
};

// Universal agents share ~/.agents/skills as their canonical dir
const UNIVERSAL_AGENTS = new Set([
  'opencode', 'codex', 'gemini-cli', 'github-copilot', 'amp', 'kimi-cli', 'replit',
]);

const CANONICAL_DIR = join(home, '.agents/skills');

// ── Helpers ────────────────────────────────────────────────────────────

function sanitizeName(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9._]+/g, '-')
    .replace(/^[.\-]+|[.\-]+$/g, '')
    .substring(0, 255) || 'unnamed-skill';
}

function ensureDir(dir) {
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

function cleanDir(dir) {
  try { rmSync(dir, { recursive: true, force: true }); } catch {}
  mkdirSync(dir, { recursive: true });
}

function copyDir(src, dest) {
  const EXCLUDE = new Set(['README.md', 'metadata.json', '.git']);
  ensureDir(dest);
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    if (EXCLUDE.has(entry.name) || entry.name.startsWith('_')) continue;
    const s = join(src, entry.name);
    const d = join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(s, d);
    } else {
      cpSync(s, d, { dereference: true });
    }
  }
}

function createSymlink(target, linkPath) {
  const resolvedTarget = resolve(target);
  const resolvedLink = resolve(linkPath);
  if (resolvedTarget === resolvedLink) return true;

  try {
    const st = lstatSync(linkPath);
    if (st.isSymbolicLink()) {
      const existing = resolve(dirname(linkPath), readlinkSync(linkPath));
      if (existing === resolvedTarget) return true;
      rmSync(linkPath);
    } else {
      rmSync(linkPath, { recursive: true });
    }
  } catch {}

  try {
    ensureDir(dirname(linkPath));
    const rel = relative(dirname(resolvedLink), resolvedTarget);
    symlinkSync(rel, linkPath);
    return true;
  } catch {
    return false;
  }
}

// ── Skill discovery ────────────────────────────────────────────────────

function findSkillsInDir(dir, fullDepth = false) {
  const skills = [];
  const seen = new Set();

  function hasSkillMd(d) {
    try { return statSync(join(d, 'SKILL.md')).isFile(); } catch { return false; }
  }

  function parseSkillMd(path) {
    try {
      const content = readFileSync(path, 'utf-8');
      // Simple frontmatter parser (avoids gray-matter dependency)
      const match = content.match(/^---\n([\s\S]*?)\n---/);
      if (!match) return null;
      const fm = {};
      for (const line of match[1].split('\n')) {
        const m = line.match(/^(\w[\w-]*)\s*:\s*(.+)$/);
        if (m) fm[m[1]] = m[2].replace(/^["']|["']$/g, '');
      }
      if (!fm.name || !fm.description) return null;
      return { name: fm.name, description: fm.description, path: dirname(path) };
    } catch { return null; }
  }

  // Check root
  if (hasSkillMd(dir)) {
    const s = parseSkillMd(join(dir, 'SKILL.md'));
    if (s && !seen.has(s.name)) { skills.push(s); seen.add(s.name); }
    if (!fullDepth) return skills;
  }

  // Search common locations
  const searchDirs = [dir, join(dir, 'skills')];
  for (const sd of searchDirs) {
    try {
      for (const entry of readdirSync(sd, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        const sub = join(sd, entry.name);
        if (hasSkillMd(sub)) {
          const s = parseSkillMd(join(sub, 'SKILL.md'));
          if (s && !seen.has(s.name)) { skills.push(s); seen.add(s.name); }
        }
      }
    } catch {}
  }

  return skills;
}

// ── Install a single skill to agents ───────────────────────────────────

function installSkill(skill, agents, mode, isGlobal) {
  const name = sanitizeName(skill.name);
  const results = [];

  // Always copy to canonical location first
  const canonicalPath = join(CANONICAL_DIR, name);
  cleanDir(canonicalPath);
  copyDir(skill.path, canonicalPath);

  for (const agent of agents) {
    if (agent === '*') {
      // Install to all known agent dirs that exist
      for (const [agentName, agentDir] of Object.entries(AGENT_GLOBAL_DIRS)) {
        if (!isGlobal) continue;
        installToAgent(name, canonicalPath, agentName, agentDir, mode);
      }
      results.push({ agent: '*', name });
      break;
    }

    const agentDir = AGENT_GLOBAL_DIRS[agent];
    if (!agentDir) {
      console.error(`     [warn] unknown agent: ${agent}`);
      continue;
    }
    installToAgent(name, canonicalPath, agent, agentDir, mode);
    results.push({ agent, name });
  }

  return results;
}

function installToAgent(skillName, canonicalPath, agentName, agentDir, mode) {
  // Universal agents already have skills in canonical dir
  if (UNIVERSAL_AGENTS.has(agentName)) return;

  const targetPath = join(agentDir, skillName);

  if (mode === 'copy') {
    cleanDir(targetPath);
    copyDir(canonicalPath, targetPath);
  } else {
    // symlink mode
    const ok = createSymlink(canonicalPath, targetPath);
    if (!ok) {
      // fallback to copy
      cleanDir(targetPath);
      copyDir(canonicalPath, targetPath);
      console.log(`     [info] symlink failed for ${agentName}, fell back to copy`);
    }
  }
}

// ── Main ───────────────────────────────────────────────────────────────

const manifestPath = process.argv[2];
if (!manifestPath) {
  console.error('Usage: install.mjs <manifest.json>');
  process.exit(1);
}

const manifest = JSON.parse(readFileSync(manifestPath, 'utf-8'));
const mode = manifest.mode || 'symlink';
const stateFile = manifest.stateFile;
const autoUpdate = manifest.autoUpdate ?? true;

console.log(`Reconciling agent skills (mode: ${mode})...`);
console.log('');

// ── Phase 1: Remove stale managed skills ─────────────────────────────
let oldState = {};
if (stateFile && existsSync(stateFile)) {
  try { oldState = JSON.parse(readFileSync(stateFile, 'utf-8')); } catch {}
}

const desiredSources = new Set(manifest.skills.map(s => s.source));
const staleSources = Object.keys(oldState).filter(s => !desiredSources.has(s));

if (staleSources.length > 0) {
  console.log('Removing skills from dropped sources...');
  for (const source of staleSources) {
    const entry = oldState[source];
    const skillNames = entry.skills || [];
    for (const name of skillNames) {
      console.log(`  <- removing ${name} (from ${source})`);
      const canonPath = join(CANONICAL_DIR, sanitizeName(name));
      try { rmSync(canonPath, { recursive: true, force: true }); } catch {}
      // Also remove from agent dirs
      for (const [agentName, agentDir] of Object.entries(AGENT_GLOBAL_DIRS)) {
        const agentPath = join(agentDir, sanitizeName(name));
        try { rmSync(agentPath, { recursive: true, force: true }); } catch {}
      }
    }
  }
  console.log('');
}

// ── Phase 2: Clone and install declared skills ───────────────────────
console.log('Installing declared skills...');
const newState = {};

for (const entry of manifest.skills) {
  const { source, agents = ['*'], skill: skillFilter = [], global: isGlobal = true, fullDepth = false } = entry;
  console.log(`  -> ${source}`);

  // Clone to temp dir
  const tmpDir = join(process.env.TMPDIR || '/tmp', `skills-nix-${Date.now()}-${Math.random().toString(36).slice(2)}`);
  try {
    execSync(`git clone --depth 1 --quiet ${source.startsWith('http') || source.startsWith('git@') ? source : `https://github.com/${source}.git`} ${tmpDir}`, {
      stdio: 'pipe',
      timeout: 30000,
    });
  } catch (e) {
    console.error(`     [warn] failed to clone: ${source}`);
    continue;
  }

  // Discover skills
  let skills = findSkillsInDir(tmpDir, fullDepth);

  // Filter if specific skills requested
  if (skillFilter.length > 0 && !skillFilter.includes('*')) {
    const filterSet = new Set(skillFilter.map(s => s.toLowerCase()));
    skills = skills.filter(s => filterSet.has(s.name.toLowerCase()));
  }

  const installedNames = [];
  for (const skill of skills) {
    installSkill(skill, agents, mode, isGlobal);
    installedNames.push(skill.name);
    console.log(`     + ${skill.name}`);
  }

  newState[source] = { skills: installedNames, agents };

  // Cleanup
  try { rmSync(tmpDir, { recursive: true, force: true }); } catch {}
}

// ── Phase 3: Write state ─────────────────────────────────────────────
if (stateFile) {
  ensureDir(dirname(stateFile));
  writeFileSync(stateFile, JSON.stringify(newState, null, 2));
}

// ── Phase 4: Update via CLI if available ─────────────────────────────
if (autoUpdate) {
  console.log('');
  console.log('Updating all skills...');
  try {
    execSync('skills update', { stdio: 'inherit', timeout: 60000 });
  } catch {
    console.log('[warn] skills update failed');
  }
}

console.log('');
console.log('Done.');
