local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assert_eq failed") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function assert_truthy(value, msg)
  if not value then
    error(msg or "assert_truthy failed")
  end
end

local function mock_vim()
  _G.vim = {
    deepcopy = function(x)
      if type(x) ~= "table" then
        return x
      end
      local out = {}
      for k, v in pairs(x) do
        out[k] = v
      end
      return out
    end,
    tbl_deep_extend = function(_, _, base, opts)
      local out = {}
      for k, v in pairs(base) do
        out[k] = v
      end
      for k, v in pairs(opts or {}) do
        out[k] = v
      end
      return out
    end,
    api = {
      nvim_create_user_command = function() end,
      nvim_buf_get_name = function() return "" end,
    },
    fn = {
      systemlist = function() return {} end,
      has = function() return 0 end,
      fnamemodify = function(path) return path end,
    },
    v = { shell_error = 0 },
    ui = { open = function() end },
    notify = function() end,
    log = { levels = { ERROR = 1 } },
  }
end

mock_vim()

local mod = dofile("./lua/bitbucket_open/init.lua")

-- parse_remote
local r1 = mod._test.parse_remote("git@bitbucket.org:veracus/home.git")
assert_eq(r1.host, "bitbucket.org", "ssh host")
assert_eq(r1.workspace, "veracus", "ssh workspace")
assert_eq(r1.repo, "home", "ssh repo")

local r2 = mod._test.parse_remote("https://bitbucket.org/veracus/home")
assert_eq(r2.host, "bitbucket.org", "https host")
assert_eq(r2.workspace, "veracus", "https workspace")
assert_eq(r2.repo, "home", "https repo")

local r3 = mod._test.parse_remote("ssh://git@bitbucket.org/veracus/home.git")
assert_eq(r3.host, "bitbucket.org", "ssh url host")
assert_eq(r3.workspace, "veracus", "ssh url workspace")
assert_eq(r3.repo, "home", "ssh url repo")

-- build_url
-- stub git calls by overriding system_call and git via monkey-patching config in module
local fake_root = "/repo"
local function fake_git(_, ...)
  local args = { ... }
  if args[1] == "config" then
    return "git@bitbucket.org:veracus/home.git"
  end
  if args[1] == "rev-parse" and args[2] == "--abbrev-ref" then
    return "main"
  end
  if args[1] == "rev-parse" and args[2] == "HEAD" then
    return "deadbeef"
  end
  return ""
end

-- Replace internal git via upvalue hack
-- We can re-require the module using a local patch by setting package.loaded
package.loaded["bitbucket_open"] = nil
_G.vim = _G.vim

-- lightweight shim: re-run file and override via debug API if available
local mod2 = dofile("./lua/bitbucket_open/init.lua")

if debug and debug.getupvalue and debug.setupvalue then
  for i = 1, 20 do
    local name = debug.getupvalue(mod2._test.build_url, i)
    if name == "git" then
      debug.setupvalue(mod2._test.build_url, i, fake_git)
      debug.setupvalue(mod2._test.current_ref, i, fake_git)
      break
    end
  end
end

local url = mod2._test.build_url(fake_root, "/repo/main.go", 0, 0)
assert_eq(url, "https://bitbucket.org/veracus/home/src/main/main.go", "url build")

local url2 = mod2._test.build_url(fake_root, "/repo/dir/file.go", 5, 5)
assert_eq(url2, "https://bitbucket.org/veracus/home/src/main/dir/file.go#lines-5", "url lines")

local url3 = mod2._test.build_url(fake_root, "/repo/dir/file.go", 3, 8)
assert_eq(url3, "https://bitbucket.org/veracus/home/src/main/dir/file.go#lines-3:8", "url range")

assert_truthy(true, "done")
print("ok")
