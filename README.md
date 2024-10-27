## gitsigns-yadm.nvim

This uses the [`gitsigns`](https://github.com/lewis6991/gitsigns.nvim) `_on_attach_pre` function to check if the currently attached buffer is file tracked by [`yadm`](https://yadm.io/), highlighting the buffer properly if it is.

## Installation

Install the plugin with your plugin manager, and then add a `_on_attach_pre` function to your [`gitsigns` configuration](https://github.com/lewis6991/gitsigns.nvim?tab=readme-ov-file#installation--usage), passing the `callback` to the `yadm_signs` function:

```lua
require('gitsigns').setup({
    _on_attach_pre = function(_, callback)
        require("gitsigns-yadm").yadm_signs(callback)
    end,
    -- other gitsigns configuration...
    on_attach = function(bufnr)
})
```

See [below](#install-examples) for examples using [`lazy`](https://github.com/folke/lazy.nvim).

## Configuration

If using a standard `yadm` setup, you likely won't need to configure anything.

The default computed values are:

```lua
{
    homedir = os.getenv("HOME"),
    yadm_repo_git = vim.fn.expand("~/.local/share/yadm/repo.git"),
    shell_timeout_ms = 2000, -- how many milliseconds to wait for yadm to finish
}
```

Call `setup` to override the defaults:

```lua
require("gitsigns-yadm").setup({
    yadm_repo_git = "~/.config/yadm/repo.git",
    shell_timeout_ms = 1000,
})
```

If you want to disable this when `yadm` is not installed, you can use `vim.fn.executable` to check before running the `callback`:

```lua
_on_attach_pre = function(_, callback)
    if vim.fn.executable("yadm") == 1 then
        require("gitsigns-yadm").yadm_signs(callback)
    else
        callback()
    end
end,
```

### Install Examples

With [`lazy`](https://github.com/folke/lazy.nvim):

```lua
{
    "lewis6991/gitsigns.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "purarue/gitsigns-yadm.nvim",
            opts = {
                shell_timeout_ms = 1000,
            },
        },
    },
    opts = {
        _on_attach_pre = function(_, callback)
            require("gitsigns-yadm").yadm_signs(callback)
        end,
        -- other configuration for gitsigns...
    },
}
```

Since this doesn't require calling `setup` (unless you want to configure the defaults), in accordance with [`lazy`s best practices](https://lazy.folke.io/developers#best-practices) you could also do the following:

```lua
{
    {
        "purarue/gitsigns-yadm.nvim",
        lazy = true,
    },
    {
        "nvim-lua/plenary.nvim",
        lazy = true,
    },
    {
        "lewis6991/gitsigns.nvim",
        opts = {
            ...
            _on_attach_pre = function(_, callback)
                require("gitsigns-yadm").yadm_signs(callback)
            end,
            ...
        }
    }
}
```
