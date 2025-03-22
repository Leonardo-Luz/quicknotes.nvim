local floatwindow = require("floatwindow")

local M = {}
local state = {
  window_config = {
    floating = {
      buf = -1,
      win = -1,
    },
    enter = true,
  },
  path = "",
  filename = "",
  data_file = "",
  notes = {},
  save_cmd = -1,
}

local clear_remaps
local remaps

local function all_notes()
  state.notes = {}
  local file = io.open(state.data_file, "r")
  if file then
    for line in file:lines() do
      line = line:gsub("^%s*(.-)%s*$", "%1")
      if line ~= "" then
        table.insert(state.notes, line)
      end
    end
    file:close()
  else
    vim.api.nvim_err_writeln("Error opening data file: " .. state.data_file)
  end
end

local function get_last_note()
  all_notes()
  if #state.notes > 0 then
    return state.notes[#state.notes]
  else
    return nil
  end
end

local function get_header()
  local lines = vim.api.nvim_buf_get_lines(state.window_config.floating.buf, 0, -1, false)
  local filename = nil
  for _, line in ipairs(lines) do
    if line:match("^#+%s*(.*)%s*$") then
      filename = line:match("^#+%s*(.*)%s*$")
      break
    end
  end

  return filename
end

local function save()
  local filename = get_header()

  if filename == nil then
    vim.api.nvim_err_writeln("No title found in buffer")
    return
  end

  local file = io.open(state.data_file, "w+")
  if not file then
    vim.api.nvim_err_writeln("Error opening file: " .. state.data_file)
    return
  end

  local found = false
  for _, note in ipairs(state.notes) do
    if note == filename then
      found = true
    elseif note ~= state.filename then
      file:write(note .. "\n")
    end
  end

  if not found then
    table.insert(state.notes, filename)
  end

  file:write(filename .. "\n")
  file:close()

  if vim.api.nvim_buf_get_changedtick(state.window_config.floating.buf) > 0 then
    local path = state.path .. "/" .. filename .. ".md"

    vim.cmd({ cmd = "update", args = { path }, bang = true })

    if state.filename ~= filename then
      local to_delete = state.path .. "/" .. state.filename .. ".md"
      vim.fn.delete(to_delete)
      if vim.api.nvim_buf_is_valid(state.window_config.floating.buf) then
        vim.api.nvim_buf_delete(state.window_config.floating.buf, { force = true })
      end

      vim.fn.delete(to_delete)
    end
  end
end

local create_note = function()
  all_notes()

  state.filename = "Note-" .. os.date("%Y%m%d-%H%M%S")

  vim.cmd(string.format("edit! %s/%s.md", state.path, state.filename))
  state.window_config.floating.buf = vim.api.nvim_get_current_buf()

  table.insert(state.notes, state.filename)

  if remaps then
    remaps()
  end

  local header = { "# " .. state.filename }
  vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, true, header)
end

local open_last_note = function()
  all_notes()
  state.filename = get_last_note()

  if state.filename == nil then
    create_note()
  else
    vim.cmd(string.format("edit! %s/%s.md", state.path, state.filename))
    state.window_config.floating.buf = vim.api.nvim_get_current_buf()
    if remaps then
      remaps()
    end
  end
end

-- WIP
local delete_note = function(filename)
  vim.ui.select({ "Yes", "No" }, {
    prompt = "Do you realy want to delete the note " .. filename,
  }, function(choice)
    if choice == "Yes" then
      local file = io.open(state.data_file, "w+")
      if not file then
        vim.api.nvim_err_writeln("Error opening file: " .. state.data_file)
        return
      end

      for _, note in ipairs(state.notes) do
        if note ~= filename then
          file:write(note .. "\n")
        end
      end

      file:close()

      local to_delete = state.path .. "/" .. filename .. ".md"
      vim.fn.delete(to_delete)
    elseif choice == "No" then
      vim.print("Note deletion cancelled")
    end
  end)
end

clear_remaps = function()
  if vim.api.nvim_buf_is_valid(state.window_config.floating.buf) then
    vim.keymap.del("n", "<esc><esc>", { buffer = state.window_config.floating.buf })
    vim.api.nvim_del_autocmd(state.save_cmd)
  end
end

remaps = function()
  vim.keymap.set("n", "<Esc><Esc>", function()
    vim.api.nvim_win_close(state.window_config.floating.win, true)
    clear_remaps()
  end, { buffer = state.window_config.floating.buf })

  state.save_cmd = vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.window_config.floating.buf,
    callback = function()
      save()
    end,
  })
end

local open_note = function(filename)
  for _, note in ipairs(state.notes) do
    if filename == note then
      state.filename = filename
      vim.cmd(string.format("edit! %s/%s.md", state.path, filename))
      state.window_config.floating.buf = vim.api.nvim_get_current_buf()
      if remaps then
        remaps()
      end
      return
    end
  end
end

M.quick_note = function()
  if not vim.api.nvim_win_is_valid(state.window_config.floating.win) then
    state.window_config.floating.buf = -1
    state.window_config.floating = floatwindow.create_floating_window(state.window_config)
    open_last_note()
  else
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end
end

M.quick_note_new = function()
  if vim.api.nvim_win_is_valid(state.window_config.floating.win) then
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end

  state.window_config.floating.buf = -1

  state.window_config.floating = floatwindow.create_floating_window(state.window_config)
  create_note()
end

M.quick_note_list = function()
  all_notes()

  local choices = {}

  for i, note in ipairs(state.notes) do
    table.insert(choices, i .. " - " .. note)
  end

  table.insert(choices, "+ New Note")

  vim.ui.select(choices, {
    prompt = "Open Note",
  }, function(choice)
    if choice == nil then
      return
    end

    if vim.api.nvim_win_is_valid(state.window_config.floating.win) then
      vim.api.nvim_win_close(state.window_config.floating.win, true)
    end

    if choice == "+ New Note" then
      M.quick_note_new()
    end

    for _, note in ipairs(state.notes) do
      local striped_choice = choice:match("-%s(.*)")

      if striped_choice == note then
        state.window_config.floating.buf = -1

        state.window_config.floating = floatwindow.create_floating_window(state.window_config)
        open_note(striped_choice)
        return
      end
    end
  end)
end

M.quick_note_delete = function()
  all_notes()

  local choices = {}
  for i, note in ipairs(state.notes) do
    table.insert(choices, i .. " - " .. note)
  end

  vim.ui.select(choices, {
    prompt = "Delete Note",
  }, function(choice)
    for _, note in ipairs(state.notes) do
      if choice == nil then
        return
      end

      local striped_choice = choice:match("-%s(.*)")

      if striped_choice == note then
        delete_note(striped_choice)
        return
      end
    end
  end)
end

vim.api.nvim_create_user_command("Quicknote", M.quick_note, {})
vim.api.nvim_create_user_command("QuicknoteList", M.quick_note_list, {})
vim.api.nvim_create_user_command("QuicknoteNew", M.quick_note_new, {})
vim.api.nvim_create_user_command("QuicknoteDelete", M.quick_note_delete, {})

M.setup = function(opts)
  state.path = opts.path

  if not state.path then
    vim.print("Set your path in your plugin config")
    return
  end

  state.data_file = string.format("%s/my-notes.txt", state.path)

  local success = os.execute("mkdir -p " .. state.path)
  if success ~= 0 then
    vim.api.nvim_err_writeln("An error occurred creating the directory: " .. state.path)
  end

  local file, err = io.open(state.data_file, "r+")
  if not file then
    vim.api.nvim_err_writeln("Error creating file '" .. state.data_file .. "': " .. err)
    return false
  end
  file:close()
end

return M
