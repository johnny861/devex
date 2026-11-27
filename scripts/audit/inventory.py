#!/usr/bin/env python3
"""Inventory installed CLI tooling and correlate it with the shell config.

Writes inventory-usage.json: every brew formula/cask/mise/pipx entry with version and the
dotfile locations that mention it, plus history-derived usage counts and live shell state.

Usage: inventory.py [output-dir]   (default: audit/raw)
"""

import collections
import datetime
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
OUT = sys.argv[1] if len(sys.argv) > 1 else "audit/raw"

DOTFILES = [
    ".zshrc",
    ".zshenv",
    ".zprofile",
    ".bashrc",
    ".bash_profile",
    ".profile",
    ".zsh/autoload.zsh",
    ".gitconfig",
]


def run(cmd):
    try:
        return subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=180
        ).stdout
    except Exception as exc:  # pragma: no cover - environment dependent
        return f"<error: {exc}>"


def collect_dotfiles():
    files = {}
    for f in DOTFILES:
        path = os.path.join(HOME, f)
        try:
            files[f] = open(path).read().splitlines()
        except OSError:
            files[f] = []
    zfunc = os.path.join(HOME, ".zsh", "zfunctions")
    if os.path.isdir(zfunc):
        for name in sorted(os.listdir(zfunc)):
            path = os.path.join(zfunc, name)
            if os.path.isfile(path):
                files[f".zsh/zfunctions/{name}"] = (
                    open(path, errors="replace").read().splitlines()
                )
    return files


def main():
    versions = {}
    for line in run("brew list --versions").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            versions[parts[0]] = parts[1]

    leaves = [l.strip() for l in run("brew leaves").splitlines() if l.strip()]
    casks = [l.strip() for l in run("brew list --cask").splitlines() if l.strip()]
    mise = [l.strip() for l in run("mise ls --global").splitlines() if l.strip()]
    pipx = [l.strip() for l in run("pipx list --short").splitlines() if l.strip()]

    dotfiles = collect_dotfiles()
    all_lines = [(f, i + 1, l) for f, ls in dotfiles.items() for i, l in enumerate(ls)]

    def refs(tool):
        rx = re.compile(r"(^|[^A-Za-z0-9_-])" + re.escape(tool) + r"([^A-Za-z0-9_-]|$)")
        return [
            f"{f}:{n}"
            for f, n, l in all_lines
            if rx.search(l) and not l.lstrip().startswith("#")
        ]

    inventory = []
    for name in sorted(set(leaves) | set(casks)):
        inventory.append(
            {
                "name": name,
                "kind": "cask" if name in casks else "formula",
                "version": versions.get(name, ""),
                "referenced_in": refs(name.split("/")[-1]),
            }
        )
    for entry in mise:
        name = entry.split()[0]
        inventory.append(
            {"name": name, "kind": "mise", "version": "", "referenced_in": refs(name)}
        )
    for entry in pipx:
        name = entry.split()[0]
        inventory.append(
            {"name": name, "kind": "pipx", "version": "", "referenced_in": refs(name)}
        )

    # ---- usage telemetry ----
    hist_path = os.path.join(HOME, ".zsh_history")
    raw = open(hist_path, "rb").read().decode("utf-8", "replace")
    commands, stamps = [], []
    for line in raw.splitlines():
        m = re.match(r"^: (\d+):\d+;(.*)$", line)
        if m:
            stamps.append(int(m.group(1)))
            commands.append(m.group(2))
        elif line and not line.startswith(": "):
            commands.append(line)

    def day(ts):
        return (
            datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
            if ts
            else "unknown"
        )

    heads = collections.Counter()
    for cmd in commands:
        cmd = cmd.strip().lstrip("$ ")
        if cmd:
            heads[re.split(r"[\s|;&]", cmd)[0]] += 1

    tools = [
        "git",
        "eza",
        "ls",
        "cd",
        "bat",
        "cat",
        "rg",
        "grep",
        "fzf",
        "aws",
        "az",
        "brew",
        "docker",
        "podman",
        "kubectl",
        "terraform",
        "node",
        "npm",
        "pnpm",
        "bun",
        "python",
        "python3",
        "uv",
        "pipx",
        "mise",
        "pyenv",
        "nvm",
        "jenv",
        "java",
        "mvn",
        "gradle",
        "dotnet",
        "go",
        "cargo",
        "code",
        "opencode",
        "tree",
        "find",
        "fd",
        "delta",
        "gh",
        "gcloud",
        "psql",
        "mongosh",
        "adb",
    ]
    tool_counts = {
        t: sum(1 for c in commands if re.match(r"^\s*" + re.escape(t) + r"(\s|$)", c))
        for t in tools
    }

    usage = {
        "history_file_bytes": os.path.getsize(hist_path),
        "commands_parsed": len(commands),
        "timestamped": len(stamps),
        "first": day(min(stamps)) if stamps else "unknown",
        "last": day(max(stamps)) if stamps else "unknown",
        "top_first_word": heads.most_common(30),
        "tool_counts": dict(sorted(tool_counts.items(), key=lambda kv: -kv[1])),
    }

    # ---- interactive state ----
    def zsh(script):
        return subprocess.run(
            ["zsh", "-i", "-c", script], capture_output=True, text=True
        ).stdout.strip()

    paths = [p for p in zsh("print -rl -- ${(s.:.)PATH}").splitlines() if p.strip()]
    dupes = {k: v for k, v in collections.Counter(paths).items() if v > 1}

    state = {
        "compdef_available": zsh("echo ${+functions[compdef]}"),
        "histsize": zsh("echo $HISTSIZE"),
        "savehist": zsh("echo $SAVEHIST"),
        "histfile": zsh("echo $HISTFILE"),
        "options_enabled": zsh("setopt").split(),
        "path_entries": len(paths),
        "path_unique": len(set(paths)),
        "path_dupes": dupes,
        "function_count": zsh("print -l ${(k)functions} | wc -l"),
    }

    os.makedirs(OUT, exist_ok=True)
    payload = {"inventory": inventory, "usage": usage, "state": state}
    with open(os.path.join(OUT, "inventory-usage.json"), "w") as f:
        json.dump(payload, f, indent=2)

    print(f"inventory rows: {len(inventory)}")
    print(f"history: {len(commands)} commands, {len(stamps)} timestamped")
    print(
        f"PATH: {len(paths)} entries, {len(set(paths))} unique, {len(dupes)} duplicated"
    )
    print(f"wrote {OUT}/inventory-usage.json")


if __name__ == "__main__":
    main()
