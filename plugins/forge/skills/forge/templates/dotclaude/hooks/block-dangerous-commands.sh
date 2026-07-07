#!/usr/bin/env bash
# PreToolUse (Bash) hook: block genuinely dangerous shell commands.
# Stack-agnostic core; protected dirs/branches come from .claude/harness.env.
# Fails open if the command can't be parsed (content-scanning hook).
#
# Detection is done in a single Python pass (shlex tokenizer) so it is robust to
# flag order (rm -fr), split flags (rm -r -f), command prefixes (git -c ... push,
# /bin/rm), and && / ; / | chaining — regex-per-line approaches leaked all of these.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Caller env wins over harness.env (keeps test fixtures deterministic regardless
# of per-project config); harness.env wins over the built-in defaults.
_PRE_PD="${PROTECTED_DIRS:-}"
_PRE_PB="${PROTECTED_BRANCHES:-}"
[ -f "$PROJECT_ROOT/.claude/harness.env" ] && . "$PROJECT_ROOT/.claude/harness.env"
PROTECTED_DIRS="${_PRE_PD:-${PROTECTED_DIRS:-src}}"
PROTECTED_BRANCHES="${_PRE_PB:-${PROTECTED_BRANCHES:-main,master}}"

INPUT="$(cat)"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

REASON="$(python3 - "$INPUT" "$PROTECTED_DIRS" "$PROTECTED_BRANCHES" <<'PY'
import json, os, shlex, sys, re

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
command = (data.get("tool_input", {}) or {}).get("command", "") or ""
if not command.strip():
    sys.exit(0)

protected_dirs = [d for d in sys.argv[2].split() if d]
protected_branches = [b for b in sys.argv[3].split(",") if b]

# Split a command line into simple commands across ; && || | and newlines.
def split_simple(cmd):
    parts, buf, i = [], [], 0
    seps = {";", "\n"}
    while i < len(cmd):
        two = cmd[i:i+2]
        if two in ("&&", "||"):
            parts.append("".join(buf)); buf = []; i += 2; continue
        c = cmd[i]
        if c in ("|",) or c in seps:
            parts.append("".join(buf)); buf = []; i += 1; continue
        buf.append(c); i += 1
    parts.append("".join(buf))
    return [p.strip() for p in parts if p.strip()]

def tokenize(s):
    try:
        return shlex.split(s)
    except ValueError:
        # Unbalanced quotes etc. — fall back to a naive split so we still inspect.
        return s.replace('"', " ").replace("'", " ").split()

def basename(tok):
    return tok.rsplit("/", 1)[-1]

def flag_letters(tokens):
    """Union of single-letter flags from -xyz style tokens (not -- long opts)."""
    letters = set()
    for t in tokens:
        if t.startswith("-") and not t.startswith("--"):
            letters.update(ch for ch in t[1:] if ch.isalpha())
    return letters

def reason_for(simple):
    toks = tokenize(simple)
    if not toks:
        return None
    argv0 = basename(toks[0])

    # env-assignment prefix (FOO=1 cmd ...) and `env`/`sudo`/`command`/`nice`/`time` wrappers
    idx = 0
    while idx < len(toks):
        t = toks[idx]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            idx += 1; continue
        if basename(t) in ("env", "sudo", "command", "nice", "time", "nohup", "xargs"):
            idx += 1
            # skip options to the wrapper
            while idx < len(toks) and toks[idx].startswith("-"):
                idx += 1
            continue
        break
    if idx >= len(toks):
        return None
    toks = toks[idx:]
    argv0 = basename(toks[0])
    rest = toks[1:]

    # --- rm: recursive AND force, order/split independent ---
    if argv0 == "rm":
        letters = flag_letters(rest)
        recursive = "r" in letters or "R" in letters
        force = "f" in letters
        if recursive and force:
            args = [t for t in rest if not t.startswith("-")]
            # root / home / unresolved var / parent traversal
            for a in args:
                if a == "/" or a.startswith("/ ") or a in ("~",) or a.startswith("~/") \
                   or a == "$HOME" or re.match(r"^\$[A-Za-z_][A-Za-z0-9_]*$", a) \
                   or a.startswith("$HOME") or "../.." in a:
                    return "rm -rf against root, home, or an unresolved variable/parent-traversal path is blocked as too risky to auto-approve."
                if a.rstrip("/") == "" and a:
                    return "rm -rf against a root-like path is blocked."
            # protected project dirs
            prot = list(protected_dirs) + [".git"]
            for a in args:
                head = a.lstrip("./").rstrip("/")
                first = head.split("/", 1)[0]
                if first in prot or head in prot:
                    return "rm -rf targeting a protected directory (%s, .git) is blocked. See .claude/rules/safety.md." % ", ".join(protected_dirs)
        return None

    # --- git: skip global options to find the subcommand ---
    if argv0 == "git":
        j = 0
        sub = None
        while j < len(rest):
            t = rest[j]
            if t in ("-C", "-c", "--namespace", "--git-dir", "--work-tree", "--exec-path"):
                j += 2; continue
            if t.startswith("-"):
                j += 1; continue
            sub = t; subargs = rest[j+1:]; break
        else:
            return None
        if sub == "push":
            has_force = any(a == "--force" or a == "-f" or
                            (a.startswith("-") and not a.startswith("--") and "f" in a[1:])
                            for a in subargs)
            lease = any(a.startswith("--force-with-lease") for a in subargs)
            if has_force and not lease:
                return "Force push is blocked (use --force-with-lease if you truly need it, and confirm with the user first)."
            for a in subargs:
                ref = a.split(":")[-1]
                if ref in protected_branches:
                    return "Push targets a protected branch (%s). Confirm with the user before pushing directly to it." % ",".join(protected_branches)
        elif sub == "reset":
            if "--hard" in subargs:
                return "git reset --hard discards uncommitted work irreversibly. Confirm with the user first."
        elif sub == "clean":
            if any(a.startswith("-") and not a.startswith("--") and "f" in a[1:] for a in subargs) or "--force" in subargs:
                return "git clean -f deletes untracked files irreversibly. Confirm with the user first."
        return None

    # --- chmod 777 / a+rwx ---
    if argv0 == "chmod":
        if any(a in ("777", "a+rwx") for a in rest):
            return "chmod 777 / a+rwx is almost never intentional. Confirm with the user first."
        return None

    # --- package publish without a dry-run flag ---
    publishers = {"npm", "yarn", "pnpm", "bun", "cargo", "gem", "twine"}
    if argv0 in publishers:
        verb = rest[0] if rest else ""
        is_publish = (verb == "publish") or (argv0 == "gem" and verb == "push") or (argv0 == "twine" and verb == "upload")
        if is_publish and "--dry-run" not in rest and "-n" not in rest:
            return "Publishing to a package registry without --dry-run is blocked. Confirm with the user first; use --dry-run to test."
        return None

    return None

# curl|wget piped into a shell is a property of the whole pipeline, checked on the raw command.
if re.search(r"(^|[|;&\s])(curl|wget)\b", command) and \
   re.search(r"\|\s*(sudo\s+)?(bash|sh|zsh|ksh|fish|dash)\b", command):
    print("Piping curl/wget output directly into a shell is blocked — download, inspect, then run.")
    sys.exit(0)

for simple in split_simple(command):
    r = reason_for(simple)
    if r:
        print(r)
        sys.exit(0)
sys.exit(0)
PY
)"

if [[ -n "$REASON" ]]; then
  python3 -c "
import json, sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': sys.argv[1]}}))
" "$REASON"
  exit 2
fi
exit 0
