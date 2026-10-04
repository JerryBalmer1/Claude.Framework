# CLAUDE.md: Claude.Framework

Claude.Framework is the controller and docs home for the seven child repos. Child code never lives in this repo.

## What agents may do

- Edit files, stage them, then stop and report what changed.
- Never commit, push, tag, rename a folder or delete anything. Jerry does those.
- One exception to the delete rule: the build prunes `.framework/test-runs/`. Each Test run, and each standalone run of `tests/`, keeps the newest 5 run folders (`-KeepRuns`) and removes older ones. It touches only folders named like a run stamp (`yyyyMMdd-HHmmss-fff`). Running the build may do this; agents do not delete there by hand.

## Where agents may read

- Read only under your working directories.
- Do not search or read anywhere else on disk. This holds even for read-only access, and even when you know the exact path.

## repos/

- `repos/` is gitignored. The Sync task fills it with clones of the child repos.
- Do not edit anything under `repos/`. The one exception: the prompt names that child repo, and the child's own CLAUDE.md allows the edit.

## survey/

- Survey skills propose new entries in `survey/*/candidates/`.
- Only Jerry promotes a candidate into the record.

## docs/standard/

- `docs/standard/` is the rulebook for docs. Agents apply its rules.
- Do not change it unless the prompt names a file in it.

## Conflicts

- If a prompt conflicts with this file, stop and say so. Do not choose one side yourself.
