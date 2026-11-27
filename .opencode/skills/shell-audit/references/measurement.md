# Measurement guide

## Commands

```sh
scripts/audit/after.py    # fast: interactive, login, clean-env medians (~30 s)
scripts/audit/run.sh      # full: startup attribution, inventory, checks (~2–3 min)
```

Both write JSON into `audit/raw/`. `*-baseline.json` files are frozen; the others are the latest
run.

## Reading `timing.json`

`scripts/audit/measure.py` builds variants of the live `.zshrc` by **deleting** lines, validates
each with `zsh -n`, then takes 20 warm runs per variant.

- `delta` = full − variant. This is the cost attributed to the removed block.
- Variants are measured in one pass, so the machine is under shared load: the `full` median in a
  variant run reads higher than a standalone `after.py` median (441 ms vs 389 ms observed).
- Use **paired** numbers. "Startup went from X to Y" is only meaningful when both were measured
  the same way, on the same machine, close in time.
- p10k's delta is 9–35 ms depending on load. Treat it as a range, not a point.
- A variant's sum of deltas exceeds the combined delta (shared `compinit` / `manpath` work).
  Attribute the overlap to "shared", not to one component.

## Validating a change

1. `zsh -n` every touched file.
2. Start a fresh **interactive** and a **non-interactive** shell; check `stderr` and the env var
   the change was about (`zsh -c 'echo $JAVA_HOME'`, `zsh -i -c ...`).
3. `env -i HOME=$HOME TERM=dumb zsh -c 'print -rl -- ${(s.:.)PATH}'` for PATH duplicates.
4. Re-run `after.py` and compare with the pre-change number.
5. Record the result in `audit/changes.md` and the plan's §9 table.
