local M = {}

---@class (exact) GitsignsYadm.Config
---@field homedir? string your home directory -- the base path yadm acts on
---@field yadm_repo_git? string the path to your yadm git repository
---@field shell_timeout_ms? number how many milliseconds to wait for yadm to finish
M.config = {
    homedir = nil,
    yadm_repo_git = nil,
    shell_timeout_ms = 2000,
}

---@param opts? GitsignsYadm.Config
local function resolve_config(opts)
    local options = opts or {}
    if M.config.homedir == nil then
        if options.homedir ~= nil then
            M.config.homedir = options.homedir
        else
            local os = require("os")
            local homedir = os.getenv("HOME")
            if homedir ~= nil then
                M.config.homedir = homedir
            end
        end
    end

    if M.config.yadm_repo_git == nil then
        if options.yadm_repo_git then
            M.config.yadm_repo_git = vim.fn.expand(options.yadm_repo_git)
        else
            local pth = vim.fn.expand("~/.local/share/yadm/repo.git")
            if (vim.uv or vim.loop).fs_stat(pth) then
                M.config.yadm_repo_git = pth
            end
        end
    end

    if options.shell_timeout_ms ~= nil then
        M.config.shell_timeout_ms = options.shell_timeout_ms
    end
end

-- NOTE: for posterity, the reason why I decided to only pass callback and not
-- the bufnr and callback is that I think that obfuscates what the _on_attach_pre is doing.
-- The vim.fn.executable() example in the README shows how to optionally
-- use yadm_signs, which makes it more obvious what to do if you wanted run your own _on_attach_pre
-- customization (e.g., first check if a file belongs to some other bare-git repo, and if
-- its not, only then import gitsigns-yadm).
-- The other possible way this could've been configured is:
-- _on_attach_pre = require("gitsigns-yadm").yadm_signs,
-- and then yadm_signs just accepts both the bufnr and callback. That is 'cleaner', but
-- it also means that gitsigns-yadm is always imported when the user configures this, not
-- when _on_attach_pre is called. The way this is configured is more complicated, but it gives
-- the user more control and perhaps understanding as to what is going on.

-- upstream logic for processing the callback value:
-- https://github.com/lewis6991/gitsigns.nvim/blob/6b1a14eabcebbcca1b9e9163a26b2f8371364cb7/lua/gitsigns/attach.lua#L120-L137

--- checks if the buffer is tracked by yadm, and sets the
--- correct toplevel and gitdir attributes if it is
---@param callback fun(_: {toplevel: string?, gitdir: string?}?): nil
---@return nil
function M.yadm_signs(callback)
    if M.config.homedir == nil or M.config.yadm_repo_git == nil then
        -- in case user did not setup the plugin, try resolving to the default config values to see if that fixes it
        resolve_config()

        if M.config.homedir == nil then
            vim.notify_once(
                'Could not determine $HOME, pass your home directory to setup() like:\nrequire("gitsigns-yadm").setup({ homedir = "/home/your_name" })',
                vim.log.levels.WARN,
                { title = "gitsigns-yadm.nvim" }
            )
            return callback()
        end
        if M.config.yadm_repo_git == nil then
            vim.notify_once(
                'Could not determine location of yadm repo, pass it to setup() like:\nrequire("gitsigns-yadm").setup({ yadm_repo_git = "~/path/to/repo.git" })',
                vim.log.levels.WARN,
                { title = "gitsigns-yadm.nvim" }
            )
            return callback()
        end
    end

    -- NOTE: without the schedule/schedule_wrap here, on some files it will block interaction
    -- and prevent the user from being able to do anything till this finishes
    -- if yadm runs particularly slow for some reason, we never want to block the UI
    --
    -- NOTE: ls-files is not processed by yadm in any way - it is passed directly on to git
    -- but the user could possibly add yadm hooks which could hang
    -- which is why shell_timeout_ms is something the user can configure
    -- https://github.com/TheLocehiliosan/yadm/blob/0a5e7aa353621bd28a289a50c0f0d61462b18c76/yadm#L149-L153
    vim.schedule(function()
        local file = vim.fn.expand("%:p")
        -- if the file is not in your home directory, skip
        if not vim.startswith(file, M.config.homedir) then
            return callback()
        end
        -- if buffer is not a file, don't do anything
        if not vim.fn.filereadable(file) then
            return callback()
        end
        -- TODO: wrap :new in-case it errors?
        -- it validates if the cmd is available with vim.fn.executable(),
        -- if yadm is not available, it will print a long traceback
        --
        -- use yadm ls-files to check if the file is tracked
        local task = require("plenary.job"):new({
            command = "yadm",
            enable_handlers = false, -- if we need to debug stdout/err, re-enable this
            enabled_recording = false,
            args = { "ls-files", "--error-unmatch", file },
            on_exit = vim.schedule_wrap(function(_, return_val)
                if return_val == 0 then
                    return callback({
                        toplevel = M.config.homedir,
                        gitdir = M.config.yadm_repo_git,
                    })
                else
                    return callback()
                end
            end),
        })
        -- first argument is true/false if it succeeded
        -- can check task.code, is 0 or 1 (yadm retcode) or nil if timeout
        local _, err = pcall(task.sync, task, M.config.shell_timeout_ms)
        if type(err) == "string" then
            vim.notify(err, vim.log.levels.ERROR, { title = "gitsigns-yadm.nvim" })
        end
    end)
end

---@param opts? GitsignsYadm.Config
function M.setup(opts)
    resolve_config(opts)
end

return M
