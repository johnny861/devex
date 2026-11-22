#!/usr/bin/env python3
"""Measure zsh startup time and attribute it to config blocks.

Builds variants of the live ~/.zshrc in a scratch directory (never in this repo, so no
secret material is copied here), validates each with `zsh -n`, then times 20 warm
interactive startups per variant.

Usage: measure.py [output-dir]   (default: audit/raw)
"""

import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

HOME = os.path.expanduser("~")
OUT = sys.argv[1] if len(sys.argv) > 1 else "audit/raw"
RUNS = 20

RC = open(os.path.join(HOME, ".zshrc")).read().splitlines()

VM_PATTERNS = [
    r"pyenv",
    r"NVM_DIR",
    r"nvm\.sh",
    r"nvm/bash_completion",
    r"jenv",
    r"mise activate",
]


def drop_patterns(lines, patterns):
    return [l for l in lines if not any(re.search(p, l) for p in patterns)]


def drop_p10k(lines):
    """Remove the instant-prompt if-block and the theme/config sources entirely."""
    out, in_block = [], False
    for l in lines:
        s = l.strip()
        if in_block:
            if s == "fi":
                in_block = False
            continue
        if s.startswith("if ") and "p10k-instant-prompt" in l:
            in_block = True
            continue
        if "p10k-instant-prompt" in l:
            continue
        if "powerlevel10k.zsh-theme" in l or s.startswith("source ~/.p10k.zsh"):
            continue
        out.append(l)
    return out


VARIANTS = {
    "full": RC,
    "no-p10k": drop_p10k(RC),
    "no-nvm": drop_patterns(RC, [r"NVM_DIR", r"nvm\.sh", r"nvm/bash_completion"]),
    "no-jenv": drop_patterns(RC, [r"jenv"]),
    "no-pyenv": drop_patterns(RC, [r"pyenv"]),
    "no-mise": drop_patterns(RC, [r"mise activate"]),
    "no-bash-my-aws": drop_patterns(RC, [r"bash-my-aws", r"BMA_"]),
    "no-plugins": drop_patterns(
        RC, [r"zsh-autosuggestions", r"zsh-syntax-highlighting"]
    ),
    "no-version-managers": drop_patterns(RC, VM_PATTERNS),
    "empty-zshrc": [],
}


def measure(env, cmd):
    for _ in range(3):
        subprocess.run(cmd, env=env, capture_output=True)
    times = []
    stderr = ""
    for _ in range(RUNS):
        t0 = time.perf_counter()
        p = subprocess.run(cmd, env=env, capture_output=True, text=True)
        times.append((time.perf_counter() - t0) * 1000)
        if not stderr and p.stderr.strip():
            stderr = p.stderr
    return {
        "median_ms": round(statistics.median(times), 1),
        "mean_ms": round(statistics.mean(times), 1),
        "min_ms": round(min(times), 1),
        "max_ms": round(max(times), 1),
        "stderr_lines": [l for l in stderr.splitlines() if l.strip()][:6],
    }


def main():
    scratch = tempfile.mkdtemp(prefix="shell-audit-")
    results = {}

    for name, lines in VARIANTS.items():
        d = os.path.join(scratch, name)
        os.makedirs(d, exist_ok=True)
        rc = os.path.join(d, ".zshrc")
        with open(rc, "w") as f:
            f.write("\n".join(lines) + "\n")
        for f in (".zshenv", ".zprofile"):
            shutil.copy(os.path.join(HOME, f), os.path.join(d, f))

        syntax = subprocess.run(["zsh", "-n", rc], capture_output=True, text=True)
        if syntax.returncode != 0:
            results[name] = {"error": syntax.stderr.strip()[:300]}
            continue

        results[name] = measure(
            dict(os.environ, ZDOTDIR=d), ["zsh", "-i", "-c", "exit"]
        )

    results["zsh-f"] = measure(dict(os.environ), ["zsh", "-f", "-c", "exit"])

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "timing.json"), "w") as f:
        json.dump(results, f, indent=2)

    base = results.get("full", {}).get("median_ms", 0)
    print(f"{'variant':24} {'median':>9} {'delta':>9}  stderr")
    for name, r in results.items():
        if "error" in r:
            print(f"{name:24} SYNTAX ERROR: {r['error']}")
            continue
        delta = base - r["median_ms"]
        print(
            f"{name:24} {r['median_ms']:8.1f}ms {delta:8.1f}ms  {len(r['stderr_lines'])}"
        )
    print(f"\nwrote {OUT}/timing.json")


if __name__ == "__main__":
    main()
