# bitbucket-open.nvim

Open the current buffer on Bitbucket in your browser.

## Features
- No external Lua dependencies
- Works with SSH or HTTPS remotes
- Optional line or range selection anchors

## Requirements
- Neovim 0.8+ (uses built-in Lua API; `vim.ui.open` used when available)
- `git` available in PATH

## Installation
Use your preferred plugin manager. Example (lazy.nvim):

```lua
{
  "veracus/bitbucket-open.nvim",
  config = function()
    require("bitbucket_open").setup()
  end,
}
```

## Usage
- `:BitbucketOpen` opens the current file
- Visual select lines and run `:'<,'>BitbucketOpen` to include line anchors
- No selection means no `#lines` fragment is added

## Configuration

```lua
require("bitbucket_open").setup({
  remote = "origin",
  host = "bitbucket.org",
  branch = "auto", -- auto | HEAD | <branch-or-commit>
  -- open_cmd = "open", -- or {"xdg-open"}
})
```

## Notes
- URL format: `https://<host>/<workspace>/<repo>/src/<ref>/<path>`
- SSH remotes like `git@bitbucket.org:workspace/repo.git` are supported

## License
MIT

## Tests
Run the minimal Lua test harness:

```sh
lua tests/run.lua
```

This uses a tiny custom runner (no external deps) and stubs Neovim APIs.
