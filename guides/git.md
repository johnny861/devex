
# git cheat sheet

Companion to [conf/.gitconfig](conf/.gitconfig). Aliases below assume that config is installed (`cp conf/.gitconfig ~/.gitconfig`).

## aliases (from .gitconfig)

```sh
git co <branch>    # checkout
git cob <branch>   # checkout -b (new branch)
git br             # branch
git brr            # branch -r (remotes)
git ci             # commit
git st             # status
git s              # status --short
git rv             # remote -v
git unstage <f>    # reset HEAD -- (unstage file)
git last           # log -1 HEAD (last commit)
git ll             # log --stat
git lg             # pretty graph log
git lgg / lga      # pretty graph log, all branches
git lol / lola     # graph oneline (lola = all branches)
git ls             # ls-files (tracked files)
git pr             # push current branch + open a PR via gh (see below)
```

## pr alias

`git pr` pushes the current branch and opens a pull request with the GitHub CLI. Args pass straight through to `gh pr create`.

```sh
# alias definition (in .gitconfig)
# pr = "!f() { git push -u origin HEAD && gh pr create \"$@\"; }; f"

git pr                       # interactive prompts
git pr --fill                # title/body from commits
git pr --fill --base main    # target a specific base branch
git pr --draft --web         # draft PR, open in browser
```

Requires the GitHub CLI: `brew install gh` then `gh auth login`.

Curl alternative (no `gh`, needs `$GH_TOKEN` and explicit owner/repo):

```sh
curl -X POST -H "Authorization: Bearer $GH_TOKEN" \
  https://api.github.com/repos/<owner>/<repo>/pulls \
  -d '{"title":"My PR","head":"my-branch","base":"main"}'
```

## status & diff

```sh
git status -sb              # short status + branch
git diff                   # unstaged changes
git diff --staged          # staged changes
git diff <a>..<b>          # between branches/commits
git diff --stat            # summary of changed files
```

## branching

```sh
git switch <branch>        # switch (modern checkout)
git switch -c <branch>     # create + switch
git branch -d <branch>     # delete (safe)
git branch -D <branch>     # force delete
git branch -m <new-name>   # rename current branch
git branch --merged        # branches merged into HEAD
```

## staging & commit

```sh
git add -p                 # stage hunks interactively
git commit --amend         # edit last commit
git commit --amend --no-edit   # add staged to last commit, keep msg
git restore <file>         # discard unstaged changes
git restore --staged <f>   # unstage (keep changes)
```

## remotes & sync

```sh
git fetch --all --prune    # fetch + drop deleted remote branches
git pull --rebase          # rebase local commits on top of upstream
git push -u origin <branch>    # push + set upstream
git push --force-with-lease    # safe force push
```

## undo & rewrite

```sh
git reset --soft HEAD~1    # undo last commit, keep changes staged
git reset --mixed HEAD~1   # undo last commit, keep changes unstaged
git reset --hard HEAD~1    # discard last commit + changes (destructive)
git revert <commit>        # new commit that undoes <commit>
git rebase -i HEAD~3       # interactively edit last 3 commits
git rebase --autosquash    # apply fixup!/squash! commits (autosquash=true in config)
git cherry-pick <commit>   # apply a commit onto current branch
```

## stash

```sh
git stash                  # stash tracked changes
git stash -u               # include untracked
git stash list             # list stashes
git stash pop              # apply + drop latest
git stash apply stash@{1}  # apply a specific stash
```

## inspect & find

```sh
git log --oneline -10      # last 10 commits, terse
git log -p <file>          # history with diffs for a file
git log -S '<text>'        # commits that add/remove <text>
git blame <file>           # who changed each line
git show <commit>          # full diff of a commit
git reflog                 # recover "lost" commits/branches
```

## git lfs (config has lfs filter enabled)

```sh
git lfs install            # set up lfs hooks
git lfs track "*.psd"      # track a file type via lfs
git lfs ls-files           # list lfs-managed files
```
