#!/usr/bin/env python3
"""Correctness and risk checks for the shell config.

Covers: clean-environment PATH, syntax of every startup file and zfunction, a redacted
secret scan, and the full stderr emitted by a startup. Writes checks.json.

Usage: checks.py [output-dir]   (default: audit/raw)
"""

import collections
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
OUT = sys.argv[1] if len(sys.argv) > 1 else "audit/raw"

STARTUP_FILES = [
    ".zshrc",
    ".zshenv",
    ".zprofile",
    ".bashrc",
    ".bash_profile",
    ".profile",
    ".zsh/autoload.zsh",
]

SECRET_PATTERNS = {
    "api_key": re.compile(
        r"(?i)\b[A-Z0-9_]*(API_KEY|APIKEY|TOKEN|SECRET|PASSWORD|PASSWD)\b\s*=\s*[\"']?[^\s\"']{8,}"
    ),
    "aws_secret": re.compile(r"(?i)AWS_SECRET_ACCESS_KEY\s*=\s*\S{8,}"),
    "private_key": re.compile(r"BEGIN [A-Z ]*PRIVATE KEY"),
    "github_pat": re.compile(r"\b(ghp|github_pat)_[A-Za-z0-9_]{20,}"),
    "openai": re.compile(r"\bsk-[A-Za-z0-9]{20,}"),
}


def main():
    checks = {}

    # ---- clean-environment PATH (no inherited pollution) ----
    clean = subprocess.run(
        [
            "env",
            "-i",
            f"HOME={HOME}",
            "TERM=dumb",
            "zsh",
            "-i",
            "-c",
            "print -rl -- ${(s.:.)PATH}",
        ],
        capture_output=True,
        text=True,
    )
    paths = [p for p in clean.stdout.splitlines() if p.strip()]
    dupes = {k: v for k, v in collections.Counter(paths).items() if v > 1}
    checks["path_clean"] = {
        "entries": len(paths),
        "unique": len(set(paths)),
        "dupes": dict(sorted(dupes.items(), key=lambda kv: -kv[1])),
    }

    # ---- startup stderr ----
    start = subprocess.run(["zsh", "-i", "-c", "exit"], capture_output=True, text=True)
    checks["startup_stderr"] = [l for l in start.stderr.splitlines() if l.strip()]

    nonlogin = subprocess.run(
        ["env", "-i", f"HOME={HOME}", "TERM=dumb", "zsh", "-i", "-c", "exit"],
        capture_output=True,
        text=True,
    )
    checks["nonlogin_stderr"] = [l for l in nonlogin.stderr.splitlines() if l.strip()]

    # ---- syntax ----
    lint = {}
    targets = []
    for f in STARTUP_FILES:
        path = os.path.join(HOME, f)
        if os.path.exists(path):
            shell = "bash" if ("bash" in f or f == ".profile") else "zsh"
            targets.append((f, path, shell))
    zfunc = os.path.join(HOME, ".zsh", "zfunctions")
    if os.path.isdir(zfunc):
        for name in sorted(os.listdir(zfunc)):
            if name.endswith((".zsh", ".sh")):
                p = os.path.join(zfunc, name)
                if os.path.isfile(p):
                    targets.append((f".zsh/zfunctions/{name}", p, "zsh"))

    for label, path, shell in targets:
        r = subprocess.run([shell, "-n", path], capture_output=True, text=True)
        lint[label] = {"ok": r.returncode == 0, "stderr": r.stderr.strip()[:300]}
    checks["syntax"] = lint

    # ---- secrets (values never recorded) ----
    findings = []
    for label in list(STARTUP_FILES) + [
        t[0] for t in targets if t[0].startswith(".zsh/zfunctions/")
    ]:
        path = os.path.join(HOME, label)
        if not os.path.isfile(path):
            continue
        for n, line in enumerate(open(path, errors="replace").read().splitlines(), 1):
            for kind, rx in SECRET_PATTERNS.items():
                if rx.search(line):
                    var = re.split(r"[=\s]", line.strip().removeprefix("export "))[0]
                    findings.append(
                        {"file": label, "line": n, "kind": kind, "var": var}
                    )
    checks["secrets"] = findings

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "checks.json"), "w") as f:
        json.dump(checks, f, indent=2)

    print(
        f"PATH (clean): {checks['path_clean']['entries']} entries, "
        f"{checks['path_clean']['unique']} unique, {len(dupes)} duplicated"
    )
    for d, n in checks["path_clean"]["dupes"].items():
        print(f"  {n}x {d}")
    print(f"startup stderr: {len(checks['startup_stderr'])} lines")
    print(
        f"syntax: {sum(1 for v in lint.values() if not v['ok'])} failures / {len(lint)} files"
    )
    print(f"secrets: {len(findings)} finding(s)")
    for s in findings:
        print(f"  {s['file']}:{s['line']} {s['kind']} ({s['var']})")
    print(f"wrote {OUT}/checks.json")


if __name__ == "__main__":
    main()
