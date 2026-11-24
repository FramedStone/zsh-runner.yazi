# zsh-runner.yazi

Run a Zsh command in Yazi. Show the output in a scrollable modal.

## Installation
```bash
ya pkg add FramedStone/zsh-runner
```

## Usage

Add this keymap to `keymap.toml` [Official Configuration](https://yazi-rs.github.io/docs/configuration/overview/):

```toml
[mgr]
prepend_keymap = [
  { on = "<C-r>", run = "plugin zsh-runner", desc = "Run Zsh command" },
]
```

Minimal vim motions supported

| Key | Action |
| --- | --- |
| `j` / `k` | Scroll one line |
| `<C-d>` / `<C-u>` | Scroll half a page |
| `g` / `G` | Jump to top / bottom |
| `q` / `<Esc>` | Close |

### Interactive programs

Programs that need a terminal, such as `lazygit`, `vim`, `htop`, or `fzf`, run in Yazi's blocking shell. The program takes the terminal. Yazi returns when the program exits.

Use a `!` prefix to force terminal mode for any command:

```
!ranger
```

## Architecture

```
          keypress
             │
             ▼
   ┌──────────────────┐
   │ ya.input         │  command prompt
   └────────┬─────────┘
            │ command
            ▼
   ┌───────────────────┐
   │ needs a terminal? │
   └───┬───────────┬───┘
       │ yes       │ no
       ▼           ▼
 ┌────────────┐  ┌──────────────────┐
 │ shell      │  │ /bin/zsh -ic     │
 │ --block    │  │ capture output   │
 └────────────┘  └────────┬─────────┘
                          │ stdout + stderr + exit code
                          ▼
                 ┌──────────────────┐
                 │ viewer state     │  lines + offset (ya.sync)
                 └────────┬─────────┘
                          │
                          ▼
                 ┌──────────────────┐
                 │ Modal            │  producer → consumer → redraw
                 └──────────────────┘
```

## Notes

- Interactive programs use the terminal, not the modal.
- Output is cut at 20 MiB.
- Stderr shows after a `[STDERR]` marker.
