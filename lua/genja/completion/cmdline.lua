-- Command-line completion.
--   :      Ex commands and their arguments (file names, :help topics): blink's cmdline source
--   / ?    words from the buffer
-- <Tab>/<S-Tab> open the menu and walk it (blink's cmdline preset); <M-j>/<M-k> walk it while it is open,
-- <M-f> as <M-k>, <M-w> to the first item, <M-s> 3 items down.
-- <Up>/<Down> are history, as in plain Vim (prefix filter included), even with the menu open; once
-- <Tab>, <S-Tab> or one of the <M-…> keys moved in the menu, they walk it too, until another key is typed.
-- <M-x> or <C-e> closes the menu.

-- true after a walk key, until another key is typed or a new command line starts
local walking = false

local WALK_KEYS = {
    [vim.keycode('<Tab>')] = true,
    [vim.keycode('<S-Tab>')] = true,
    [vim.keycode('<M-j>')] = true,
    [vim.keycode('<M-k>')] = true,
    [vim.keycode('<M-f>')] = true,
    [vim.keycode('<M-w>')] = true,
    [vim.keycode('<M-s>')] = true,
    [vim.keycode('<Up>')] = true,
    [vim.keycode('<Down>')] = true,
}

-- once per session: setup() may run again (:EnableLang, reloads)
local watching = false

local function watch_keys()
    if watching then
        return
    end
    watching = true
    vim.on_key(function(key, typed)
        if vim.fn.mode() ~= 'c' then
            return
        end
        if not WALK_KEYS[typed ~= '' and typed or key] then
            walking = false
        end
    end, vim.api.nvim_create_namespace('genja.completion.cmdline'))
    vim.api.nvim_create_autocmd('CmdlineEnter', {
        group = vim.api.nvim_create_augroup('genja.completion.cmdline', { clear = true }),
        callback = function()
            walking = false
        end,
    })
end

-- first command of a walk key: mark the walk, then let the rest of the list run
local function mark()
    walking = true
end

---@param select 'select_next'|'select_prev'
local function history_or(select)
    return function(cmp)
        if walking and cmp.is_menu_visible() then
            return cmp[select]()
        end
    end
end

---Select the first item of the open menu; blink has no command for it.
---@param cmp blink.cmp.API
---@return boolean|nil
local function select_first(cmp)
    if not cmp.is_menu_visible() then
        return
    end
    vim.schedule(function()
        require('blink.cmp.completion.list').select(1)
    end)
    return true
end

---For tests: is <Up>/<Down> walking the menu now?
---@return boolean
local function is_walking()
    return walking
end

---@type genja.completion.Feature
local function feature(config)
    watch_keys()

    ---@type blink.cmp.CmdlineConfigPartial
    config.cmdline = {
        keymap = {
            preset = 'cmdline',
            ['<Tab>'] = { mark, 'show_and_insert_or_accept_single', 'select_next' },
            ['<S-Tab>'] = {
                mark,
                function(cmp) return cmp.show_and_insert_or_accept_single({ initial_selected_item_idx = -1 }) end,
                'select_prev',
            },
            ['<M-j>'] = { mark, 'select_next', 'fallback' },
            ['<M-k>'] = { mark, 'select_prev', 'fallback' },
            ['<M-f>'] = { mark, 'select_prev', 'fallback' }, -- the other way from <M-j>
            ['<M-w>'] = { mark, select_first, 'fallback' },
            ['<M-s>'] = {
                mark,
                function(cmp) return cmp.select_next({ count = 3 }) end,
                'fallback',
            },
            ['<Down>'] = { history_or('select_next'), 'fallback' },
            ['<Up>'] = { history_or('select_prev'), 'fallback' },
            ['<M-x>'] = { 'cancel', 'fallback' }, -- as <C-e>: close the menu, undo the inserted item
        },
        sources = function()
            local type = vim.fn.getcmdtype()
            if type == '/' or type == '?' then
                return { 'buffer' }
            end
            if type == ':' or type == '@' then
                return { 'cmdline' }
            end
            return {}
        end,
        completion = {
            menu = { auto_show = true }, -- as with nvim-cmp's cmdline setup
            -- no preselect: the menu opens with nothing selected, so the first <Tab> inserts item 1
            -- (:term<Tab> gives :terminal); the preset preselects 1 and <Tab> went to item 2
            list = { selection = { preselect = false, auto_insert = true } },
        },
    }
end

return setmetatable({ is_walking = is_walking }, {
    __call = function(_, config)
        feature(config)
    end,
})
