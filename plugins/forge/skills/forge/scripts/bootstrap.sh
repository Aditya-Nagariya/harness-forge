#!/usr/bin/env bash
# forge bootstrap: deterministically install or upgrade the self-improving harness
# into a target project from the template tree next to this script.
#
# Usage:
#   bootstrap.sh --target DIR [--set KEY=VALUE]... [--house-rules FILE]
#
# Zones (see GUIDE.md):
#   HARNESS CODE  (hooks, skills, agents, workflows, rules, evals, settings.json,
#                  statusline.sh, loop.md, state/status.schema.json)
#     - fresh install: copied
#     - upgrade: overwritten ONLY if the installed copy is pristine (its sha256
#       matches the hash recorded in forge-manifest.json at install time).
#       User-modified files are left untouched; the new version is written
#       alongside as <name>.forge-new for manual/LLM-assisted merge.
#   USER DATA     (harness.env, memory/, issues-solved/, tasks/, state/status.json,
#                  CLAUDE.md, CLAUDE.local.md, .worktreeinclude)
#     - copied only if absent. NEVER overwritten by an upgrade.
#
# Substitution: {{KEY}} placeholders in *.tmpl files and CLAUDE.md.tmpl are replaced
# from --set pairs; {{HOUSE_RULES}} / {{HOUSE_RULES_BULLETS}} from --house-rules FILE;
# {{DATE}} and {{FORGE_VERSION}} are provided automatically.
#
# Records .claude/forge-manifest.json (version, date, per-file sha256, substitutions).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$SKILL_DIR/templates"
FORGE_VERSION="$(python3 -c "import json; print(json.load(open('$SKILL_DIR/../../.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "unknown")"

TARGET=""
SETS=()
HOUSE_RULES_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --set) SETS+=("$2"); shift 2 ;;
    --house-rules) HOUSE_RULES_FILE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "usage: bootstrap.sh --target DIR [--set KEY=VALUE]... [--house-rules FILE]" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

export FORGE_TEMPLATES="$TEMPLATES"
export FORGE_TARGET="$TARGET"
export FORGE_VERSION
export FORGE_HOUSE_RULES_FILE="$HOUSE_RULES_FILE"
export FORGE_SETS="$(printf '%s\n' "${SETS[@]+"${SETS[@]}"}")"

python3 - <<'PY'
import hashlib, json, os, shutil, sys
from datetime import datetime, timezone

templates = os.environ["FORGE_TEMPLATES"]
target = os.environ["FORGE_TARGET"]
version = os.environ["FORGE_VERSION"]
house_rules_file = os.environ.get("FORGE_HOUSE_RULES_FILE", "")

subs = {}
for line in os.environ.get("FORGE_SETS", "").splitlines():
    line = line.strip()
    if line and "=" in line:
        k, v = line.split("=", 1)
        subs[k] = v
subs.setdefault("DATE", datetime.now(timezone.utc).strftime("%Y-%m-%d"))
subs["FORGE_VERSION"] = version
house_rules = "(none configured — run /forge to fill project conventions)"
if house_rules_file and os.path.exists(house_rules_file):
    house_rules = open(house_rules_file, encoding="utf-8").read().strip()
subs["HOUSE_RULES"] = house_rules
subs["HOUSE_RULES_BULLETS"] = house_rules

import re as _re
_PLACEHOLDER = _re.compile(r"\{\{(\w+)\}\}")
def substitute(text):
    # Single pass: a value that itself contains a {{KEY}} literal (e.g. house-rules
    # text documenting templating) is NOT re-scanned, and an unknown key is left
    # verbatim on purpose (validate.sh reports genuinely-missing keys separately).
    return _PLACEHOLDER.sub(lambda m: subs.get(m.group(1), m.group(0)), text)

def has_unsubstituted(text):
    return any(m.group(1) not in subs for m in _PLACEHOLDER.finditer(text))

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()

manifest_path = os.path.join(target, ".claude", "forge-manifest.json")
old_manifest = {}
if os.path.exists(manifest_path):
    try:
        old_manifest = json.load(open(manifest_path))
    except Exception:
        old_manifest = {}
old_hashes = old_manifest.get("files", {})
mode = "upgrade" if old_hashes else "new"

# USER-DATA relative paths (under .claude/ unless noted): copy only if absent.
USER_DATA_PREFIXES = ("memory/", "issues-solved/", "tasks/", "agent-memory/")
USER_DATA_FILES = {"harness.env", "state/status.json"}

installed, skipped_data, conflicts, updated = [], [], [], []
new_hashes = {}

dotclaude_src = os.path.join(templates, "dotclaude")
for root, dirs, files in os.walk(dotclaude_src):
    for fname in files:
        src = os.path.join(root, fname)
        rel = os.path.relpath(src, dotclaude_src)
        out_rel = rel[:-5] if rel.endswith(".tmpl") else rel
        dst = os.path.join(target, ".claude", out_rel)
        content = substitute(open(src, encoding="utf-8").read())

        is_data = out_rel in USER_DATA_FILES or any(out_rel.startswith(p) for p in USER_DATA_PREFIXES)

        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if is_data:
            if os.path.exists(dst):
                skipped_data.append(out_rel)
            else:
                open(dst, "w", encoding="utf-8").write(content)
                installed.append(out_rel)
            continue

        # harness code zone
        key = ".claude/" + out_rel
        if os.path.exists(dst) and mode == "upgrade":
            current = sha256(dst)
            recorded = old_hashes.get(key)
            tmp = dst + ".forge-tmp"
            open(tmp, "w", encoding="utf-8").write(content)
            incoming = sha256(tmp)
            if current == incoming:
                os.remove(tmp)
                new_hashes[key] = current
                continue
            if recorded and current != recorded:
                # user modified it — never clobber
                os.replace(tmp, dst + ".forge-new")
                conflicts.append(out_rel)
                new_hashes[key] = current
                continue
            os.replace(tmp, dst)
            updated.append(out_rel)
            new_hashes[key] = incoming
        else:
            open(dst, "w", encoding="utf-8").write(content)
            installed.append(out_rel)
            new_hashes[key] = sha256(dst)

# Root-level files (all user-data semantics: copy only if absent)
root_map = {
    "CLAUDE.md.tmpl": "CLAUDE.md",
    "CLAUDE.local.md.example": "CLAUDE.local.md",
    "worktreeinclude": ".worktreeinclude",
}
for src_name, dst_name in root_map.items():
    src = os.path.join(templates, src_name)
    dst = os.path.join(target, dst_name)
    if not os.path.exists(src):
        continue
    if os.path.exists(dst):
        skipped_data.append(dst_name)
        continue
    open(dst, "w", encoding="utf-8").write(substitute(open(src, encoding="utf-8").read()))
    installed.append(dst_name)

# gitignore: append snippet once (marker-guarded)
gi_snippet = open(os.path.join(templates, "gitignore.snippet"), encoding="utf-8").read()
gi_path = os.path.join(target, ".gitignore")
marker = "--- harness (added by /forge) ---"
existing = open(gi_path, encoding="utf-8").read() if os.path.exists(gi_path) else ""
if marker not in existing:
    open(gi_path, "a", encoding="utf-8").write(gi_snippet)
    installed.append(".gitignore (snippet appended)")
else:
    skipped_data.append(".gitignore (snippet already present)")

# GUIDE.md: harness code zone at .claude/GUIDE.md
guide_src = os.path.join(templates, "GUIDE.md")
if os.path.exists(guide_src):
    dst = os.path.join(target, ".claude", "GUIDE.md")
    key = ".claude/GUIDE.md"
    content = substitute(open(guide_src, encoding="utf-8").read())
    if os.path.exists(dst) and mode == "upgrade" and old_hashes.get(key) and sha256(dst) != old_hashes[key]:
        open(dst + ".forge-new", "w", encoding="utf-8").write(content)
        conflicts.append("GUIDE.md")
        new_hashes[key] = sha256(dst)
    else:
        open(dst, "w", encoding="utf-8").write(content)
        (updated if mode == "upgrade" else installed).append("GUIDE.md")
        new_hashes[key] = sha256(dst)

# harness.env key reconciliation: on upgrade, harness.env is preserved (user data),
# but a newer template may introduce a new KEY the hooks now read. Append any keys
# present in the template but missing from the installed file (commented, with the
# template default) so a new guard is never silently disabled after upgrade.
env_keys_added = []
if mode == "upgrade":
    env_tmpl = os.path.join(templates, "dotclaude", "harness.env.tmpl")
    env_dst = os.path.join(target, ".claude", "harness.env")
    if os.path.exists(env_tmpl) and os.path.exists(env_dst):
        import re as _re2
        def env_keys(text):
            return [m.group(1) for m in _re2.finditer(r"^([A-Z_][A-Z0-9_]*)=", text, _re2.MULTILINE)]
        tmpl_text = substitute(open(env_tmpl, encoding="utf-8").read())
        tmpl_lines = tmpl_text.splitlines()
        installed_keys = set(env_keys(open(env_dst, encoding="utf-8").read()))
        missing = [k for k in env_keys(tmpl_text) if k not in installed_keys]
        if missing:
            with open(env_dst, "a", encoding="utf-8") as f:
                f.write("\n# --- keys added by forge upgrade %s (review and set) ---\n" % version)
                for k in missing:
                    line = next((l for l in tmpl_lines if l.startswith(k + "=")), '%s=""' % k)
                    f.write("# " + line + "\n")
            env_keys_added = missing

# Orphan pruning: a file present in the OLD manifest but not written this run was
# removed/renamed in the newer template. If the on-disk copy is still pristine
# (hash matches the old manifest), delete it; otherwise leave it and warn, since
# the user may have come to rely on their modified version.
orphans_removed, orphans_kept = [], []
if mode == "upgrade":
    for key, old_hash in old_hashes.items():
        if key in new_hashes:
            continue
        # key is repo-relative (".claude/..."); resolve against target root
        abspath = os.path.join(target, key)
        if not os.path.exists(abspath):
            continue
        if sha256(abspath) == old_hash:
            os.remove(abspath)
            orphans_removed.append(key)
        else:
            orphans_kept.append(key)

manifest = {
    "forge_version": version,
    "mode": mode,
    "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "substitutions": {k: v for k, v in subs.items() if k not in ("HOUSE_RULES", "HOUSE_RULES_BULLETS")},
    "files": new_hashes,
}
os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
json.dump(manifest, open(manifest_path, "w"), indent=2)

print(f"mode: {mode}")
print(f"installed: {len(installed)}")
for f in installed: print(f"  + {f}")
if updated:
    print(f"updated (pristine): {len(updated)}")
    for f in updated: print(f"  ~ {f}")
if conflicts:
    print(f"CONFLICTS (user-modified; new version at <file>.forge-new): {len(conflicts)}")
    for f in conflicts: print(f"  ! {f}")
if orphans_removed:
    print(f"pruned (removed from newer template, was pristine): {len(orphans_removed)}")
    for f in orphans_removed: print(f"  - {f}")
if orphans_kept:
    print(f"ORPHANS KEPT (removed from template but you modified them — review/delete manually): {len(orphans_kept)}")
    for f in orphans_kept: print(f"  ? {f}")
if env_keys_added:
    print(f"harness.env: {len(env_keys_added)} new key(s) appended (commented, review & set): {', '.join(env_keys_added)}")
print(f"preserved user data: {len(skipped_data)}")
PY

# Executable bits on all shell scripts we may have installed
find "$TARGET/.claude" -name "*.sh" -exec chmod +x {} +

echo "bootstrap complete (forge $FORGE_VERSION)"
