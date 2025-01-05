local floatwindow = require("floatwindow")

local M = {}

local state = {
  window_config = {
    floating = {},
    enter = true,
  },
  path = "",
}

M.quick_note = function()
  local filename = "test"

  state.window_config.floating = floatwindow.create_floating_window(state.window_config)

  vim.cmd(string.format("edit %s/%s.md", state.path, filename))

  vim.api.nvim_create_autocmd("bufLeave", {
    buffer = state.window_config.floating.buf,
    callback = function()
      vim.cmd(string.format("w %s/%s.md", state.path, filename))
    end,
  })
end

vim.api.nvim_create_user_command("Quicknote", M.quick_note, {})

---@class floatnotes.Setup
---@field path string: String to where the notes will be saved

---setup floatnotes plugin
---@param opts floatnotes.Setup
M.setup = function(opts)
  state.path = opts.path
end

return M
