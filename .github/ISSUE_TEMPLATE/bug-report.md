---
name: Bug Report
about: Report a bug with the plugin
title: 'bug: '
labels: ''
assignees: purarue

---

**Describe the bug**

A clear and concise description of what the bug is.

**To Reproduce**

Minimal config to reproduce the issue:

```lua
for name, url in pairs({
  gitsigns = "https://github.com/lewis6991/gitsigns.nvim",
  gitsigns_yadm = "https://github.com/purarue/gitsigns-yadm.nvim"
  -- ADD OTHER PLUGINS _NECESSARY_ TO REPRODUCE THE ISSUE
}) do
  local install_path = vim.fn.fnamemodify("gitsigns_issue/" .. name, ":p")
  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({ "git", "clone", "--depth=1", url, install_path })
  end
  vim.opt.runtimepath:append(install_path)
end

require("gitsigns").setup({
  debug_mode = true, -- You must add this to enable debug messages
  -- ADD GITSIGNS CONFIG THAT IS _NECESSARY_ FOR REPRODUCING THE ISSUE
  _on_attach_pre = function(bufnr, callback)
    require("gitsigns-yadm").yadm_signs(callback, { bufnr = bufnr })
  end,
})
```

Put the above in `init-repro.lua` and run `nvim -u init-repro.lua ...`

**Expected behavior**

A clear and concise description of what you expected to happen.

**Screenshots**

If applicable, add screenshots to help explain your problem.

**Desktop (please complete the following information):**
 - OS: [e.g. Linux]
 - nvim version
