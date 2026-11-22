import json
import os
import statistics
import subprocess
import time

HOME = os.path.expanduser("~")
OUT = "/Users/michaelhunter/projects/repos/johnny861/devex/audit/raw"


def measure(cmd, env=None, runs=20):
    for _ in range(3):
        subprocess.run(cmd, env=env, capture_output=True)
    ts, err = [], ""
    for _ in range(runs):
        t0 = time.perf_counter()
        p = subprocess.run(cmd, env=env, capture_output=True, text=True)
        ts.append((time.perf_counter() - t0) * 1000)
        if not err and p.stderr.strip():
            err = p.stderr
    return {
        "median_ms": round(statistics.median(ts), 1),
        "mean_ms": round(statistics.mean(ts), 1),
        "min_ms": round(min(ts), 1),
        "max_ms": round(max(ts), 1),
        "stderr_lines": len([l for l in err.splitlines() if l.strip()]),
    }


result = {
    "captured": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "note": "post-remediation: nvm -> mise, jenv -> static JAVA_HOME",
    "interactive": measure(["zsh", "-i", "-c", "exit"]),
    "login": measure(["zsh", "-l", "-i", "-c", "exit"]),
    "clean_nonlogin": measure(
        ["env", "-i", f"HOME={HOME}", "TERM=dumb", "zsh", "-i", "-c", "exit"]
    ),
}

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "timing-after.json"), "w") as f:
    json.dump(result, f, indent=2)

for k, v in result.items():
    if isinstance(v, dict):
        print(
            f"{k:16} median {v['median_ms']:7.1f} ms  max {v['max_ms']:7.1f}  stderr {v['stderr_lines']}"
        )
