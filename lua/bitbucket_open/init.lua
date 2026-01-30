local M = {}

local defaults = {
  remote = "origin",
  host = "bitbucket.org",
  branch = "auto", -- auto | HEAD | <branch-or-commit>
  open_cmd = nil, -- string or list; if nil use vim.ui.open or OS fallback
}

local config = vim.deepcopy(defaults)

local function system_call(args)
  if vim.system then
    local result = vim.system(args, { text = true }):wait()
    return result.code, result.stdout or "", result.stderr or ""
  end

  local output = vim.fn.systemlist(args)
  if vim.v.shell_error ~= 0 then
    return vim.v.shell_error, "", table.concat(output, "\n")
  end

  return 0, table.concat(output, "\n"), ""
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function git(root, ...)
  local args = { "git", "-C", root }
  for i = 1, select("#", ...) do
    table.insert(args, select(i, ...))
  end
  local code, out, err = system_call(args)
  if code ~= 0 then
    return nil, err
  end
  return trim(out), nil
end

local function git_root(path)
  local root, err = git(path, "rev-parse", "--show-toplevel")
  if not root or root == "" then
    return nil, err or "not a git repository"
  end
  return root, nil
end

local function parse_remote(url)
  if not url or url == "" then
    return nil
  end

  url = trim(url)
  url = url:gsub("%.git$", "")

  local host, path
  if url:match("^git@") then
    host, path = url:match("^git@([^:]+):(.+)$")
  elseif url:match("^ssh://") then
    host, path = url:match("^ssh://git@([^/]+)/(.+)$")
  elseif url:match("^https?://") then
    host, path = url:match("^https?://([^/]+)/(.+)$")
  elseif url:match("^git://") then
    host, path = url:match("^git://([^/]+)/(.+)$")
  end

  if not host or not path then
    return nil
  end

  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end

  if #parts < 2 then
    return nil
  end

  return {
    host = host,
    workspace = parts[1],
    repo = parts[2],
  }
end

local function current_ref(root)
  if config.branch == "auto" then
    local branch = git(root, "rev-parse", "--abbrev-ref", "HEAD")
    if branch == "HEAD" or not branch or branch == "" then
      return git(root, "rev-parse", "HEAD")
    end
    return branch
  end

  if config.branch == "HEAD" then
    return git(root, "rev-parse", "HEAD")
  end

  return config.branch
end

local function build_url(root, file_path, range_start, range_end)
  local remote_url = git(root, "config", "--get", "remote." .. config.remote .. ".url")
  if not remote_url or remote_url == "" then
    return nil, "remote not found: " .. config.remote
  end

  local remote = parse_remote(remote_url)
  if not remote then
    return nil, "unable to parse remote url"
  end

  local host = config.host or remote.host
  if not host or host == "" then
    return nil, "host not configured"
  end

  local ref = current_ref(root)
  if not ref or ref == "" then
    return nil, "unable to determine git ref"
  end

  local rel = file_path
  if rel:sub(1, #root + 1) == root .. "/" then
    rel = rel:sub(#root + 2)
  end

  local url = string.format("https://%s/%s/%s/src/%s/%s", host, remote.workspace, remote.repo, ref, rel)

  if range_start and range_end and range_start > 0 and range_end > 0 then
    if range_start == range_end then
      url = url .. string.format("#lines-%d", range_start)
    else
      url = url .. string.format("#lines-%d:%d", range_start, range_end)
    end
  end

  return url, nil
end

local function open_url(url)
  if config.open_cmd then
    if type(config.open_cmd) == "string" then
      system_call({ config.open_cmd, url })
    elseif type(config.open_cmd) == "table" then
      local args = vim.deepcopy(config.open_cmd)
      table.insert(args, url)
      system_call(args)
    end
    return
  end

  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return
  end

  if vim.fn.has("mac") == 1 then
    system_call({ "open", url })
  elseif vim.fn.has("win32") == 1 then
    system_call({ "cmd", "/c", "start", url })
  else
    system_call({ "xdg-open", url })
  end
end

function M.open(range_start, range_end)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("bitbucket-open: current buffer has no file", vim.log.levels.ERROR)
    return
  end

  local file_path = vim.fn.fnamemodify(file, ":p")
  local root, err = git_root(vim.fn.fnamemodify(file_path, ":h"))
  if not root then
    vim.notify("bitbucket-open: " .. err, vim.log.levels.ERROR)
    return
  end

  local url, build_err = build_url(root, file_path, range_start, range_end)
  if not url then
    vim.notify("bitbucket-open: " .. build_err, vim.log.levels.ERROR)
    return
  end

  open_url(url)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  vim.api.nvim_create_user_command("BitbucketOpen", function(cmd)
    M.open(cmd.line1, cmd.line2)
  end, { range = true })
end

M.setup()

return M
