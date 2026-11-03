-- mason writes packages/<pkg>/mason-receipt.json as the last step of an install. A package folder
-- without one is a cut-off install or update: on Windows the old folder can't be deleted while its
-- server runs (locked exe, open log), so the new version stays in mason/staging/<pkg>, and the
-- launcher in mason/bin and the receipt are never written. mason still counts the folder as
-- installed (it only checks that the folder exists), so nothing reinstalls it by itself.
--
--   require('genja.lsp.receipt').list()        every package folder without a receipt
--   require('genja.lsp.receipt').check(name)   the same for one package: two stats
--
-- Used by :checkhealth genja.lsp (lsp/health.lua), the repair on open (lsp/init.lua) and the
-- config's tests/comps011. No requires: the tests load it with dofile.

local M = {}

---@class genja.lsp.Broken
---@field name string mason package name
---@field path string its folder in mason/packages
---@field staged boolean the new version is still in mason/staging

---mason's root folder: its own setting when mason is loaded, else the default.
---@return string
function M.root_dir()
    local ok, settings = pcall(require, 'mason.settings')
    if ok and settings.current and settings.current.install_root_dir then
        return settings.current.install_root_dir
    end
    return vim.fs.joinpath(vim.fn.stdpath('data'), 'mason')
end

---A package whose folder exists but has no receipt; nil when fine or not installed.
---@param name string mason package name
---@return genja.lsp.Broken|nil
function M.check(name)
    local root = M.root_dir()
    local path = vim.fs.joinpath(root, 'packages', name)
    local stat = vim.uv.fs_stat(path)
    if not stat or stat.type ~= 'directory' then
        return nil
    end
    if vim.uv.fs_stat(vim.fs.joinpath(path, 'mason-receipt.json')) then
        return nil
    end
    local staged = vim.uv.fs_stat(vim.fs.joinpath(root, 'staging', name)) ~= nil
    return { name = name, path = path, staged = staged }
end

---Every package folder without a receipt, sorted by name.
---@return genja.lsp.Broken[]
function M.list()
    local result = {}
    local packages = vim.fs.joinpath(M.root_dir(), 'packages')
    if not vim.uv.fs_stat(packages) then
        return result
    end
    for name, kind in vim.fs.dir(packages) do
        if kind == 'directory' then
            local broken = M.check(name)
            if broken then
                table.insert(result, broken)
            end
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

---What to do about a package without a receipt.
---@param broken genja.lsp.Broken
---@return string
function M.fix(broken)
    if broken.name == 'lua-language-server' then
        -- the target kills running lua_ls first; they hold the old folder's files
        return 'make mason-luals in the nvim config folder'
    end
    return 'stop its server (quit the other nvims), then :MasonInstall --force ' .. broken.name
end

return M
