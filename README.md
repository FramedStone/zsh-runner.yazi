# zsh-runner.yazi

Run a Zsh command in Yazi. Show the output in a scrollable modal.

## Usage

Add this keymap to `keymap.toml`:

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
   ┌──────────────────┐
   │ /bin/zsh -ic     │  run in current directory
   └────────┬─────────┘
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

- Output is cut at 20 MiB.
- Stderr shows after a `[STDERR]` marker.
