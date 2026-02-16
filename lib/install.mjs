#!/usr/bin/env node
/**
 * Declarative skill installer — bypasses the skills CLI to call the JS API
 * directly, supporting both symlink and copy install modes.
 *
 * Usage:
 *   install.mjs [--force] <manifest.json>
 *
 * Manifest format:
 * {
 *   "mode": "symlink" | "copy",
 *   "stateFile": "/path/to/managed.json",
 *   "autoUpdate": true,
 *   "skills": [
 *     {
 *       "source": "owner/repo" | "/local/path" | "./relative",
 *       "agents": ["opencode", "claude-code"],
 *       "skill": ["specific-skill"],
 *       "fullDepth": false
 *     }
 *   ]
 * }
 */

import { execSync, exec } from "child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  readdirSync,
  cpSync,
  symlinkSync,
  lstatSync,
  readlinkSync,
  rmSync,
  statSync,
} from "fs";
import { join, dirname, relative, resolve } from "path";
import { homedir } from "os";
import { promisify } from "util";

const execAsync = promisify(exec);

// ── CLI flags ──────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const cliForce = argv.includes("--force");
const cliVerbose = argv.includes("--verbose");
const manifestPath = argv.find((a) => !a.startsWith("--"));

// ── Logging ────────────────────────────────────────────────────────────
const noop = () => {};
const log = {
  install: cliVerbose ? (msg) => console.log(`  📦 ${msg}`) : noop,
  remove: cliVerbose ? (msg) => console.log(`  🗑️  ${msg}`) : noop,
  skip: cliVerbose ? (msg) => console.log(`  ⏭️  ${msg}`) : noop,
  warn: (msg) => console.error(`  ⚠️  ${msg}`),
  error: (msg) => console.error(`  ❌ ${msg}`),
  done: (msg) => console.log(`  ✅ ${msg}`),
  info: cliVerbose ? (msg) => console.log(`  ℹ️  ${msg}`) : noop,
  header: cliVerbose ? (msg) => console.log(`\n${msg}`) : noop,
};

// ── Stats tracking ─────────────────────────────────────────────────────
const stats = { installed: 0, skipped: 0, failed: 0, removed: 0 };

// ── Constants ──────────────────────────────────────────────────────────
const home = homedir();
const configHome = process.env.XDG_CONFIG_HOME || join(home, ".config");

const AGENT_GLOBAL_DIRS = {
  opencode: join(configHome, "opencode/skills"),
  "claude-code": join(
    process.env.CLAUDE_CONFIG_DIR || join(home, ".claude"),
    "skills",
  ),
  cursor: join(home, ".cursor/skills"),
  codex: join(process.env.CODEX_HOME || join(home, ".codex"), "skills"),
  "gemini-cli": join(home, ".gemini/skills"),
  "github-copilot": join(home, ".copilot/skills"),
  amp: join(configHome, "agents/skills"),
  antigravity: join(home, ".gemini/antigravity/skills"),
  cline: join(home, ".cline/skills"),
  goose: join(configHome, "goose/skills"),
  roo: join(home, ".roo/skills"),
  windsurf: join(home, ".codeium/windsurf/skills"),
  trae: join(home, ".trae/skills"),
  kilo: join(home, ".kilocode/skills"),
  "kiro-cli": join(home, ".kiro/skills"),
  droid: join(home, ".factory/skills"),
};

const CANONICAL_DIR = join(home, ".agents/skills");

// ── Helpers ────────────────────────────────────────────────────────────

function sanitizeName(name) {
  return (
    name
      .toLowerCase()
      .replace(/[^a-z0-9._]+/g, "-")
      .replace(/^[.\-]+|[.\-]+$/g, "")
      .substring(0, 255) || "unnamed-skill"
  );
}

function ensureDir(dir) {
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

function cleanDir(dir) {
  try {
    rmSync(dir, { recursive: true, force: true });
  } catch {}
  mkdirSync(dir, { recursive: true });
}

function copyDir(src, dest) {
  const EXCLUDE = new Set(["README.md", "metadata.json", ".git"]);
  ensureDir(dest);
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    if (EXCLUDE.has(entry.name) || entry.name.startsWith("_")) continue;
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
  } catch (e) {
    log.warn(`symlink failed: ${e.message}`);
    return false;
  }
}

// ── Source detection ────────────────────────────────────────────────────

function isLocalSource(source) {
  if (
    source.startsWith("/") ||
    source.startsWith("./") ||
    source.startsWith("../")
  ) {
    return true;
  }
  if (source.startsWith("~")) return true;
  // Check if it looks like a path (not owner/repo pattern)
  if (
    !source.includes("/") ||
    source.startsWith("git@") ||
    source.startsWith("http")
  ) {
    return false;
  }
  // owner/repo pattern — check if it happens to be a local directory
  const expanded = source.replace(/^~/, home);
  try {
    return statSync(expanded).isDirectory();
  } catch {
    return false;
  }
}

function resolveLocalSource(source) {
  return resolve(source.replace(/^~/, home));
}

function gitUrl(source) {
  if (source.startsWith("http") || source.startsWith("git@")) return source;
  return `https://github.com/${source}.git`;
}

// ── Git helpers ────────────────────────────────────────────────────────

function getRemoteCommitHash(source) {
  try {
    const url = gitUrl(source);
    const output = execSync(`git ls-remote --heads ${url} HEAD`, {
      stdio: "pipe",
      timeout: 15000,
      encoding: "utf-8",
    });
    // ls-remote output: <hash>\t<ref>
    const match = output.match(/^([a-f0-9]+)/);
    return match ? match[1] : null;
  } catch {
    // Fallback: try ls-remote without specifying HEAD
    try {
      const url = gitUrl(source);
      const output = execSync(`git ls-remote ${url}`, {
        stdio: "pipe",
        timeout: 15000,
        encoding: "utf-8",
      });
      const match = output.match(/^([a-f0-9]+)\s+HEAD$/m);
      return match ? match[1] : null;
    } catch {
      return null;
    }
  }
}

function getLocalCommitHash(dir) {
  try {
    return execSync("git rev-parse HEAD", {
      cwd: dir,
      stdio: "pipe",
      encoding: "utf-8",
    }).trim();
  } catch {
    return null;
  }
}

async function cloneRepoAsync(source, tmpDir) {
  const url = gitUrl(source);
  await execAsync(`git clone --depth 1 --quiet ${url} ${tmpDir}`, {
    timeout: 30000,
  });
}

// ── Skill discovery ────────────────────────────────────────────────────

function findSkillsInDir(dir, fullDepth = true) {
  const skills = [];
  const seen = new Set();

  function hasSkillMd(d) {
    try {
      return statSync(join(d, "SKILL.md")).isFile();
    } catch {
      return false;
    }
  }

  function parseSkillMd(path) {
    try {
      const content = readFileSync(path, "utf-8");
      const match = content.match(/^---\n([\s\S]*?)\n---/);
      if (!match) return null;
      const fm = {};
      for (const line of match[1].split("\n")) {
        const m = line.match(/^(\w[\w-]*)\s*:\s*(.+)$/);
        if (m) fm[m[1]] = m[2].replace(/^["']|["']$/g, "");
      }
      if (!fm.name || !fm.description) return null;
      return {
        name: fm.name,
        description: fm.description,
        path: dirname(path),
      };
    } catch (e) {
      log.warn(`failed to parse ${path}: ${e.message}`);
      return null;
    }
  }

  function scanDir(d) {
    if (hasSkillMd(d)) {
      const s = parseSkillMd(join(d, "SKILL.md"));
      if (s && !seen.has(s.name)) {
        skills.push(s);
        seen.add(s.name);
      }
      if (!fullDepth) return;
    }

    try {
      for (const entry of readdirSync(d, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue;
        if (entry.name === ".git" || entry.name === "node_modules") continue;
        scanDir(join(d, entry.name));
      }
    } catch {}
  }

  scanDir(dir);
  return skills;
}

// ── Install a single skill to agents ───────────────────────────────────

function installSkill(skill, agents, mode) {
  const name = sanitizeName(skill.name);
  const results = [];

  // Copy to canonical location
  const canonicalPath = join(CANONICAL_DIR, name);
  cleanDir(canonicalPath);
  copyDir(skill.path, canonicalPath);

  for (const agent of agents) {
    if (agent === "*") {
      for (const [agentName, agentDir] of Object.entries(AGENT_GLOBAL_DIRS)) {
        installToAgent(name, canonicalPath, agentName, agentDir, mode);
      }
      results.push({ agent: "*", name });
      break;
    }

    const agentDir = AGENT_GLOBAL_DIRS[agent];
    if (!agentDir) {
      log.warn(`unknown agent: ${agent}`);
      continue;
    }
    installToAgent(name, canonicalPath, agent, agentDir, mode);
    results.push({ agent, name });
  }

  return results;
}

function installToAgent(skillName, canonicalPath, agentName, agentDir, mode) {
  if (resolve(agentDir) === resolve(CANONICAL_DIR)) return;

  const targetPath = join(agentDir, skillName);

  if (mode === "copy") {
    cleanDir(targetPath);
    copyDir(canonicalPath, targetPath);
  } else {
    const ok = createSymlink(canonicalPath, targetPath);
    if (!ok) {
      cleanDir(targetPath);
      copyDir(canonicalPath, targetPath);
      log.warn(`symlink failed for ${agentName}, fell back to copy`);
    }
  }
}

// ── Main ───────────────────────────────────────────────────────────────

if (!manifestPath) {
  console.error("Usage: install.mjs [--force] <manifest.json>");
  process.exit(1);
}

if (!existsSync(manifestPath)) {
  log.error(`manifest not found: ${manifestPath}`);
  process.exit(1);
}

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf-8"));
} catch (e) {
  log.error(`failed to parse manifest: ${e.message}`);
  process.exit(1);
}

const mode = manifest.mode || "symlink";
const autoUpdate = manifest.autoUpdate ?? true;
const force = cliForce;

// Resolve shell-style variables in stateFile path
const stateHome = process.env.XDG_STATE_HOME || join(home, ".local/state");
const stateFile = manifest.stateFile
  ? manifest.stateFile
      .replace(/\$\{XDG_STATE_HOME:-[^}]*\}/g, stateHome)
      .replace(/\$HOME/g, home)
      .replace(/~/g, home)
  : null;

log.header(`Reconciling agent skills (mode: ${mode})...`);

// ── Phase 1: Remove stale managed skills ─────────────────────────────
let oldState = {};
if (stateFile && existsSync(stateFile)) {
  try {
    oldState = JSON.parse(readFileSync(stateFile, "utf-8"));
  } catch (e) {
    log.warn(`failed to read state file: ${e.message}`);
  }
}

const desiredSources = new Set(manifest.sources.map((s) => s.source));
const staleSources = Object.keys(oldState).filter(
  (s) => !desiredSources.has(s),
);

if (staleSources.length > 0) {
  log.header("Removing skills from dropped sources...");
  for (const source of staleSources) {
    const entry = oldState[source];
    const skillNames = entry.skills || [];
    for (const name of skillNames) {
      log.remove(`${name} (from ${source})`);
      const canonPath = join(CANONICAL_DIR, sanitizeName(name));
      try {
        rmSync(canonPath, { recursive: true, force: true });
      } catch (e) {
        log.warn(`failed to remove canonical: ${e.message}`);
      }
      for (const [, agentDir] of Object.entries(AGENT_GLOBAL_DIRS)) {
        const agentPath = join(agentDir, sanitizeName(name));
        try {
          rmSync(agentPath, { recursive: true, force: true });
        } catch {}
      }
      stats.removed++;
    }
  }
}

// ── Phase 2: Prepare sources (clone or resolve local) ────────────────

async function prepareSource(entry) {
  const { source } = entry;

  if (isLocalSource(source)) {
    const localPath = resolveLocalSource(source);
    if (!existsSync(localPath)) {
      throw new Error(`local source not found: ${localPath}`);
    }
    const commitHash = getLocalCommitHash(localPath);
    return { dir: localPath, commitHash, isLocal: true, cleanup: () => {} };
  }

  // Check cache — skip if hash unchanged and not forced
  const oldEntry = oldState[source];
  if (!force && oldEntry && oldEntry.commitHash) {
    const remoteHash = getRemoteCommitHash(source);
    if (remoteHash && remoteHash === oldEntry.commitHash) {
      return { cached: true, commitHash: remoteHash };
    }
  }

  const tmpDir = join(
    process.env.TMPDIR || "/tmp",
    `skills-nix-${Date.now()}-${Math.random().toString(36).slice(2)}`,
  );

  await cloneRepoAsync(source, tmpDir);

  const commitHash = getLocalCommitHash(tmpDir);
  return {
    dir: tmpDir,
    commitHash,
    isLocal: false,
    cleanup: () => {
      try {
        rmSync(tmpDir, { recursive: true, force: true });
      } catch {}
    },
  };
}

// ── Phase 3: Install declared skills ─────────────────────────────────
log.header("Installing declared skills...");
const newState = {};

async function processEntry(entry) {
  const {
    source,
    agents = ["*"],
    skill: skillFilter = [],
    fullDepth = true,
  } = entry;

  try {
    const prepared = await prepareSource(entry);

    if (prepared.cached) {
      log.skip(
        `${source} (unchanged, hash: ${prepared.commitHash.slice(0, 8)})`,
      );
      // Preserve old state
      newState[source] = oldState[source];
      stats.skipped++;
      return;
    }

    // Discover skills
    let skills = findSkillsInDir(prepared.dir, fullDepth);

    if (skillFilter.length > 0 && !skillFilter.includes("*")) {
      const filterSet = new Set(skillFilter.map((s) => s.toLowerCase()));
      skills = skills.filter((s) => filterSet.has(s.name.toLowerCase()));
    }

    if (skills.length === 0) {
      log.warn(`no skills found in ${source}`);
      prepared.cleanup?.();
      return;
    }

    const installedNames = [];
    for (const skill of skills) {
      installSkill(skill, agents, mode);
      installedNames.push(skill.name);
      log.install(`${skill.name} (from ${source})`);
      stats.installed++;
    }

    newState[source] = {
      skills: installedNames,
      agents,
      commitHash: prepared.commitHash,
    };

    prepared.cleanup?.();
  } catch (e) {
    log.error(`failed to process ${source}: ${e.message}`);
    stats.failed++;
    // Preserve old state if available so we don't lose track
    if (oldState[source]) {
      newState[source] = oldState[source];
    }
  }
}

// Process all entries in parallel
const results = await Promise.allSettled(
  manifest.sources.map((entry) => processEntry(entry)),
);
for (const result of results) {
  if (result.status === "rejected") {
    log.error(`unexpected failure: ${result.reason?.message || result.reason}`);
    stats.failed++;
  }
}

// ── Phase 4: Write state ─────────────────────────────────────────────
if (stateFile) {
  try {
    ensureDir(dirname(stateFile));
    writeFileSync(stateFile, JSON.stringify(newState, null, 2));
  } catch (e) {
    log.error(`failed to write state file: ${e.message}`);
  }
}

// ── Phase 5: Update via CLI if available ─────────────────────────────
if (autoUpdate && manifest.skillsBin) {
  log.header("Updating all skills...");
  try {
    execSync(`${manifest.skillsBin} update`, {
      stdio: "inherit",
      timeout: 60000,
    });
  } catch {
    log.warn("skills update failed");
  }
}

// ── Summary ──────────────────────────────────────────────────────────
log.header("Summary:");
const parts = [];
if (stats.installed > 0) parts.push(`${stats.installed} installed`);
if (stats.skipped > 0) parts.push(`${stats.skipped} skipped (cached)`);
if (stats.removed > 0) parts.push(`${stats.removed} removed`);
if (stats.failed > 0) parts.push(`${stats.failed} failed`);
if (parts.length === 0) parts.push("nothing to do");
log.done(parts.join(", "));

if (stats.failed > 0) {
  process.exit(1);
}
