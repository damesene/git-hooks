# Git hooks
This repository provides client git hooks which used for other projects.

Copy all files from `client-hooks` directory to `.git/hooks/` in other project.

## Scripts
For easy hooks application are included scripts which copy latest version of hooks and copy them to target folder.

You must run the script only once after clone repository or when the hooks were updated.

## Included hooks
The hooks below are applied.

### commit-msg
Commit message must be in requested format based on [Conventional Commits](https://www.conventionalcommits.org).