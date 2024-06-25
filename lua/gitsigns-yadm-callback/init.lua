local M = {}

---@class (exact) YadmCallback.Config
---@field homedir? string
---@field yadm_repo_git? string
M.Config = {
    homedir = nil,
    yadm_repo_git = nil,
}

local function resolve_config()
    if M.Config.homedir == nil then
        -- if default config has not been computed yet, compute it
        local os = require("os")
        local homedir = os.getenv("HOME")
        if homedir ~= nil then
            M.Config.homedir = homedir
        end
    end

    if M.Config.yadm_repo_git == nil then
        M.Config.yadm_repo_git = vim.fn.expand("~/.local/share/yadm/repo.git")
    end
end

--- gitsigns yadm support
---@param callback fun(cb_value: {toplevel: string, gitdir: string}?): nil
---@return nil
function M.yadm_signs(callback)
    resolve_config()
    if M.Config.homedir == nil or M.Config.yadm_repo_git == nil then
        vim.notify(
            'Could not determine $HOME or yadm repo.git path, please pass a second argument to yadm_signs like { homedir = "/home/your_name", yadm_repo_git = vim.fn.expand("~/.path/to/yadm/repo.git") }',
            vim.log.levels.WARN
        )
        return callback()
    end

    vim.schedule(function()
        -- if buffer is not a file, don't do anything
        local file = vim.fn.expand("%:p")
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
                            toplevel = M.Config.homedir,
                            gitdir = M.Config.yadm_repo_git,
                        })
                    else
                        return callback()
                    end
                end),
            })
            :sync()
    end)
end

return M
