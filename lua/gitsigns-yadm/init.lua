local M = {}

---@class (exact) GitsignsYadm.Config
---@field homedir? string
---@field yadm_repo_git? string
M.config = {
    homedir = nil,
    yadm_repo_git = nil,
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
end

--- checks if the buffer is tracked by yadm, and sets the
--- correct toplevel and gitdir attributes if it is
---@param callback fun(_: {toplevel: string, gitdir: string}?): nil
---@return nil
function M.yadm_signs(callback)
    if M.config.homedir == nil or M.config.yadm_repo_git == nil then
        -- in case user did not setup the plugin, try resolving to the default config values to see if that fixes it
        resolve_config()

        if M.config.homedir == nil then
            vim.notify_once(
                'Could not determine $HOME, pass your home directory to setup() like:\nrequire("gitsigns-yadm").setup({ homedir = "/home/your_name" })',
                vim.log.levels.WARN,
                { title = 'gitsigns-yadm.nvim' }
            )
            return callback()
        end
        if M.config.yadm_repo_git == nil then
            vim.notify_once(
                'Could not determine location of yadm repo, pass it to setup() like:\nrequire("gitsigns-yadm").setup({ yadm_repo_git = "~/path/to/repo.git" })',
                vim.log.levels.WARN,
                { title = 'gitsigns-yadm.nvim' }
            )
            return callback()
        end
    end

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
        -- use yadm ls-files to check if the file is tracked
        require("plenary.job")
            :new({
                command = "yadm",
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
            :sync()
    end)
end

---@param opts? GitsignsYadm.Config
function M.setup(opts)
    resolve_config(opts)
end

return M
