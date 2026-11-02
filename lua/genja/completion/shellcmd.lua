-- Shell command names after `!` and `:terminal`, from a file in stdpath('state').
-- getcompletion(..., 'shellcmd') scans every $PATH dir, which is slow on Windows, so the list is
-- kept on disk and rebuilt in the background when PATH changes or after 3 hours.
local source = require('genja.completion.source')

local SRC = 'genja-completion011/shellcmd.lua: '
local MAX_AGE = 3 * 60 * 60
local FILE = vim.fs.joinpath(vim.fn.stdpath('state'), 'genja-completion011', 'shellcmd.txt')

-- stops a second rebuild while one is queued or running; the list itself is on disk
local building = false

-- :vert, :tab, :bot … in front of :terminal; the same list as genja/ext/term.lua
local MODIFIERS = { 'vertical', 'horizontal', 'tab', 'botright', 'topleft', 'aboveleft', 'belowright',
    'leftabove', 'rightbelow' }

---@param word string
---@param full string
---@return boolean true when word is at least 2 chars and a start of full
local function is_abbrev(word, full)
    return #word >= 2 and vim.startswith(full, word)
end

---Whether the words are modifiers and then a :terminal abbreviation, as in `:vert term`.
---@param words string[]
---@return boolean
local function terminal_cmd(words)
    local last = table.remove(words)
    if last == nil or not is_abbrev(last, 'terminal') then
        return false
    end
    for _, word in ipairs(words) do
        local known = false
        for _, mod in ipairs(MODIFIERS) do
            known = known or is_abbrev(word, mod)
        end
        if not known then
            return false
        end
    end
    return true
end

---The word being typed after `!` or `:terminal`; nil when the line is anything else.
---@param line string text of the command line up to the cursor
---@return string|nil
local function shell_word(line)
    local bang = line:match('^!([^%s]*)$')
    if bang then
        return bang
    end
    local head, word = line:match('^(.-)%s+([^%s]*)$')
    if head and terminal_cmd(vim.split(head, '%s+', { trimempty = true })) then
        return word
    end
    return nil
end

---Rebuild the cache file, one scan at a time.
local function rebuild()
    if building then
        return
    end
    building = true
    vim.schedule(function()
        local names = vim.fn.getcompletion('', 'shellcmd')
        table.insert(names, 1, 'PATH=' .. (vim.env.PATH or ''))
        vim.fn.mkdir(vim.fs.dirname(FILE), 'p')
        if vim.fn.writefile(names, FILE) ~= 0 then
            vim.notify(SRC .. 'cannot write ' .. FILE, vim.log.levels.WARN)
        end
        building = false
    end)
end

---The names in the cache file and whether they are fresh; nil when the file is missing or was
---made for another PATH.
---@return string[]|nil names
---@return boolean fresh
local function read_cache()
    if vim.fn.filereadable(FILE) == 0 then
        return nil, false
    end
    local lines = vim.fn.readfile(FILE)
    if lines[1] ~= 'PATH=' .. (vim.env.PATH or '') then
        return nil, false
    end
    local age = os.time() - vim.fn.getftime(FILE)
    table.remove(lines, 1)
    return lines, age < MAX_AGE
end

---blink items: the cached names; a stale or missing list is rebuilt for the next keystroke.
---@return lsp.CompletionItem[]
local function items()
    local names, fresh = read_cache()
    if not fresh then
        rebuild()
    end
    return source.labels(names or {}, source.kind.Function)
end

local M = {}

---Whether the command line is at a shell command name, for the cmdline sources function.
---@return boolean
function M.active()
    if vim.fn.getcmdtype() ~= ':' then
        return false
    end
    local line = vim.fn.getcmdline():sub(1, vim.fn.getcmdpos() - 1)
    return shell_word(line) ~= nil
end

---Delete the cache file; the next `!` or `:terminal` name rebuilds it.
local function reset()
    if vim.fn.filereadable(FILE) == 0 then
        vim.notify(SRC .. 'no path cache to delete', vim.log.levels.INFO)
        return
    end
    if vim.fn.delete(FILE) ~= 0 then
        vim.notify(SRC .. 'cannot delete ' .. FILE, vim.log.levels.ERROR)
        return
    end
    vim.notify(SRC .. 'deleted ' .. FILE, vim.log.levels.INFO)
end

---Add the `shellcmd` provider and :ResetPathCache; cmdline.lua lists the provider when M.active().
---@param config blink.cmp.Config
function M.register(config)
    vim.api.nvim_create_user_command('ResetPathCache', reset, {
        desc = 'Delete the shell command list for ! and :terminal completion',
        force = true,
    })
    source.register(config, 'shellcmd', {
        only = true,
        -- the word after `!` or a space: `!ca` replaces `ca`
        replace = '[^!%s]*',
        -- asked again on each keystroke, so a list that was still building shows once it is there
        incomplete = true,
        items = items,
    })
end

return M
