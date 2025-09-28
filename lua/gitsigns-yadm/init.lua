local M = {}

---@class (exact) GitsignsYadm.OnYadmAttachEvent
---@field file string the filename being attached to
---@field bufnr number the buffer number being attached to

---@class (exact) GitsignsYadm.Config
---@field homedir? string your home directory -- the base path yadm acts on
---@field yadm_repo_git? string the path to your yadm git repository
---@field disable_inside_gitdir? boolean disable if CWD is in a git repository
---@field on_yadm_attach? fun(event: GitsignsYadm.OnYadmAttachEvent): nil callback function that is called when we successfully attach to a yadm file
---@field shell_timeout_ms? number how many milliseconds to wait for yadm to finish
M.config = {
    homedir = nil,
    yadm_repo_git = nil,
    shell_timeout_ms = 2000,
    disable_inside_gitdir = true,
    on_yadm_attach = nil,
}

local has_setup = false

---@param opts? GitsignsYadm.Config
local function resolve_config(opts)
    -- stylua: ignore
    if has_setup then return end
    has_setup = true

    M.config = vim.tbl_extend("force", M.config, opts or {})
    -- default to vim.env.HOME if unset
    M.config.homedir = M.config.homedir or vim.env.HOME
    if M.config.yadm_repo_git == nil then
        local repo_path = vim.fs.normalize("~/.local/share/yadm/repo.git")
        if (vim.uv or vim.loop).fs_stat(repo_path) then
            M.config.yadm_repo_git = repo_path
        end
    else
        -- expand if user passed in something like ~/path/to/repo.git
        if vim.startswith(M.config.yadm_repo_git, "~") then
            M.config.yadm_repo_git = vim.fs.normalize(M.config.yadm_repo_git)
        end
    end
end

---@return boolean true if we should return early
local function _validate_config()
    if M.config.homedir == nil then
        vim.notify_once(
            'Could not determine $HOME, pass your home directory to setup() like:\nrequire("gitsigns-yadm").setup({ homedir = "/home/your_name" })',
            vim.log.levels.WARN,
            { title = "gitsigns-yadm.nvim" }
        )
        return true
    end
    if M.config.yadm_repo_git == nil then
        vim.notify_once(
            'Could not determine location of yadm repo, pass it to setup() like:\nrequire("gitsigns-yadm").setup({ yadm_repo_git = "~/path/to/repo.git" })',
            vim.log.levels.WARN,
            { title = "gitsigns-yadm.nvim" }
        )
        return true
    end
    return false
end

---@param file string
---@param callback fun(_: {toplevel: string?, gitdir: string?}?): nil
---@param bufnr number
function M._run_gitsigns_attach(file, callback, bufnr)
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return callback()
    end

    -- TODO: wrap :new in-case it errors?
    -- it validates if the cmd is available with vim.fn.executable(),
    -- if yadm is not available, it will print a long traceback
    --
    -- use yadm ls-files to check if the file is tracked
    ---@diagnostic disable: missing-fields
    local task = require("plenary.job"):new({
        command = "yadm",
        enable_handlers = false, -- if we need to debug stdout/err, re-enable this
        enabled_recording = false,
        args = { "ls-files", "--error-unmatch", file },
        on_exit = vim.schedule_wrap(function(_, return_val)
            -- check to make sure the buffer hasn't closed since
            -- we started the task. If the buffer is gone, skip custom callback
            if not vim.api.nvim_buf_is_loaded(bufnr) then
                return callback()
            end
            if return_val == 0 then
                -- callback for gitsigns, this means we're attaching to a yadm file
                callback({
                    toplevel = M.config.homedir,
                    gitdir = M.config.yadm_repo_git,
                })
                -- user callback, if supplied
                if M.config.on_yadm_attach ~= nil then
                    M.config.on_yadm_attach({ file = file, bufnr = bufnr })
                end
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
end

-- https://github.com/nvim-telescope/telescope.nvim/blob/78857db9e8d819d3cc1a9a7bdc1d39d127a36495/lua/telescope/utils.lua#L555
--
---@param cmd? string[] List of arguments to pass
---@param cwd? string Working directory for job
---@return number? ret
function M._cmd_returncode(cmd, cwd)
    ---@diagnostic disable-next-line: param-type-mismatch
    local command = table.remove(cmd, 1)
    local _, ret = require("plenary.job")
        :new({
            command = command,
            args = cmd,
            cwd = cwd,
        })
        :sync()
    return ret
end

function M._inside_gitdir()
    return M._cmd_returncode({ "git", "rev-parse", "--is-inside-work-tree" }) == 0
end

---@class (exact) GitsignsYadm.YadmSignsOptions
---@field bufnr number? -- the buffer being attached to

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
---@param options GitsignsYadm.YadmSignsOptions?
function M.yadm_signs(callback, options)
    local opts = options or {}
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

    -- run setup in-case user did not pass opts or call setup
    resolve_config()

    -- if home or gitdir is not set, warns, calls the callback to
    -- end _on_attach_pre and returns early
    if _validate_config() then
        callback()
        return
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
        -- this is an optimization -- if we're already in a git directory
        -- as specified by 'git rev-parse --is-inside-work-tree', then
        -- we skip the yadm call.
        --
        -- On my machine, the git command runs in 2ms, while the
        -- yadm command can take about 120ms.
        if M.config.disable_inside_gitdir and M._inside_gitdir() then
            return callback()
        end

        -- expand to full path
        local file = vim.api.nvim_get_bufname(bufnr)

        -- if the file is not in your home directory,
        -- skip checking if yadm should attach
        if not vim.startswith(file, M.config.homedir) then
            return callback()
        end

        -- if the file is in the *git* directory, e.g.
        -- COMMIT_EDITMSG, skip checking if yadm should attach
        if vim.startswith(file, M.config.yadm_repo_git) then
            return callback()
        end

        -- if buffer is not a file, don't do anything
        if not vim.fn.filereadable(file) then
            return callback()
        end

        -- run yadm ls-files to check if this file matches
        M._run_gitsigns_attach(file, callback, bufnr)
    end)
end

---@param opts? GitsignsYadm.Config
function M.setup(opts)
    resolve_config(opts)
end

return M
