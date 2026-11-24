# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Run interactive programs (`lazygit`, `vim`, `htop`, ...) in terminal mode.
- Add a `!` prefix to force terminal mode.

### Changed

- Rename the repo to `zsh-runner.yazi` so that `ya pkg` can install it.

## [1.0.0] - 2026-11-24

### Added

- Run a Zsh command in the current directory.
- Show stdout and stderr in a scrollable modal.
- Scroll keys: `j`/`k`, `<C-d>`/`<C-u>`, `g`/`G`, `q`.
- Truncate output to 20 MiB.
