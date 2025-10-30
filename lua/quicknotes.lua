local floatwindow = require("floatwindow")
local Path = require("plenary.path")

local create_command = vim.api.nvim_create_user_command

local M = {}
local state = {
  window_config = {
    floating = {
      buf = -1,
      win = -1,
    },
    enter = true,
  },
  title = nil,
  notes = {},
  save_cmd_id = -1,
  cur_filename = "",
  dir = vim.fn.stdpath("data") .. "/quicknotes",
  quick_dir = vim.fn.stdpath("data") .. "/quicknotes",
}

local clear_remaps
local remaps

local function new_note_path(filename)
  return Path:new(state.quick_dir, filename)
end

--- Read a note file
local function read_note(filename)
  local note_file = new_note_path(filename)
  if note_file:exists() then
    return note_file:readlines()
  end
  return {}
end

--- Write to a note file
local function write_note(filename, data)
  local note_file = Path:new(state.quick_dir, filename)
  note_file:write(data, "w")
end

--- Ensure filename ends with .md
local function ensure_md_ext(name)
  if not name:match("%.md$") then
    return name .. ".md"
  end
  return name
end

--- Get all notes from directory (.md only)
local function all_notes()
  state.notes = {}
  local dir = state.quick_dir
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    vim.print("Cannot open notes directory: " .. dir)
    return
  end
  while true do
    local name, t = vim.loop.fs_scandir_next(handle)
    if not name then break end
    if t == "file" and name:match("%.md$") then
      table.insert(state.notes, name)
    end
  end
  -- sort by modification time (newest first)
  table.sort(state.notes, function(a, b)
    local a_stat = vim.loop.fs_stat(dir .. "/" .. a)
    local b_stat = vim.loop.fs_stat(dir .. "/" .. b)
    return (a_stat and a_stat.mtime.sec or 0) > (b_stat and b_stat.mtime.sec or 0)
  end)
end

--- Get last note (newest by modification time)
local function get_last_note()
  all_notes()
  if state.notes and state.notes[1] then
    return state.notes[1]
  else
    return nil
  end
end

--- Extract first markdown header as filename
local function get_header()
  local lines = vim.api.nvim_buf_get_lines(state.window_config.floating.buf, 0, -1, false)
  for _, line in ipairs(lines) do
    local header = line:match("^#+%s*(.*)%s*$")
    if header and #header > 0 then
      return header
    end
  end
  return nil
end

local function get_current_note_lines()
  return vim.api.nvim_buf_get_lines(state.window_config.floating.buf, 0, -1, false)
end

--- Save current note
local function save()
  local new_filename = ensure_md_ext(get_header() or state.cur_filename)
  local old_filename = ensure_md_ext(state.cur_filename)

  if not new_filename then
    vim.print("No title found in buffer")
    return
  end

  if new_filename ~= old_filename then
    local old_path = new_note_path(old_filename)
    local new_path = new_note_path(new_filename)
    if old_path:exists() then
      old_path:rename({ new_name = tostring(new_path) })
    end
    state.cur_filename = new_filename
  end

  local lines = table.concat(get_current_note_lines(), "\n")
  write_note(new_filename, lines)
end

--- Create a new note
local create_note = function()
  all_notes()
  if vim.api.nvim_win_is_valid(state.window_config.floating.win) then
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end

  state.cur_filename = "Note-" .. os.date("%Y%m%d-%H%M%S") .. ".md"
  state.window_config.floating = floatwindow.create_floating_window(state.window_config)
  table.insert(state.notes, state.cur_filename)

  if remaps then remaps() end

  local header = { "# " .. state.cur_filename:gsub("%.md$", "") }
  vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, true, header)
  vim.bo[vim.api.nvim_get_current_buf()].filetype = "markdown"

  write_note(state.cur_filename, table.concat(header, "\n"))
end

--- Delete note
local delete_note = function(filename)
  vim.ui.select({ "Yes", "No" }, {
    prompt = "Really delete note " .. filename .. "?",
  }, function(choice)
    if choice == "Yes" then
      local to_delete = state.quick_dir .. "/" .. filename
      if vim.fn.delete(to_delete) == 0 then
        vim.print("Deleted " .. filename)
      else
        vim.print("Failed to delete " .. filename)
      end
    else
      vim.print("Note deletion cancelled")
    end
  end)
end

--- Clear keymaps
clear_remaps = function()
  if vim.api.nvim_buf_is_valid(state.window_config.floating.buf) then
    vim.keymap.del("n", "<esc><esc>", { buffer = state.window_config.floating.buf })
    vim.api.nvim_del_autocmd(state.save_cmd_id)
  end
end

--- Create keymaps
remaps = function()
  vim.keymap.set("n", "<Esc><Esc>", function()
    vim.api.nvim_win_close(state.window_config.floating.win, true)
    clear_remaps()
  end, { buffer = state.window_config.floating.buf })

  state.save_cmd_id = vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.window_config.floating.buf,
    callback = function()
      save()
    end,
  })
end

--- Open selected note
local open_note = function(filename)
  for _, note in ipairs(state.notes) do
    if filename == note then
      state.cur_filename = filename
      if vim.api.nvim_win_is_valid(state.window_config.floating.win) then
        vim.api.nvim_win_close(state.window_config.floating.win, true)
      end
      state.window_config.floating = floatwindow.create_floating_window(state.window_config)
      if remaps then remaps() end

      local lines = read_note(filename)
      vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, false, lines)
      vim.bo[vim.api.nvim_get_current_buf()].filetype = "markdown"
      return
    end
  end
end

--- Open last note or create new
local open_last_note = function()
  state.cur_filename = get_last_note()
  if state.cur_filename == nil then
    create_note()
  else
    open_note(state.cur_filename)
  end
end

--- Toggle quick note window
M.quick_note = function()
  if not vim.api.nvim_win_is_valid(state.window_config.floating.win) then
    open_last_note()
  else
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end
end

--- Create new note
M.quick_note_new = function()
  create_note()
end

--- List notes menu
M.quick_note_list = function()
  all_notes()
  local choices = {}
  for i, note in ipairs(state.notes) do
    table.insert(choices, i .. " - " .. note)
  end
  table.insert(choices, "+ New Note")

  vim.ui.select(choices, { prompt = "Open Note" }, function(choice)
    if not choice then return end
    if choice == "+ New Note" then
      M.quick_note_new()
      return
    end

    local striped_choice = choice:match("-%s(.*)")
    if striped_choice then open_note(striped_choice) end
  end)
end

--- Delete note menu
M.quick_note_delete = function()
  all_notes()
  local choices = {}
  for i, note in ipairs(state.notes) do
    table.insert(choices, i .. " - " .. note)
  end
  table.insert(choices, "X - Cancel")

  vim.ui.select(choices, { prompt = "Delete Note" }, function(choice)
    if not choice or choice == "X - Cancel" then return end
    local striped_choice = choice:match("-%s(.*)")
    if striped_choice then delete_note(striped_choice) end
  end)
end

---@class Opts
---@field custom_path string
---@field quick_dir string
---@field keys table
---@field commands table

--- Setup
---@param opts Opts
M.setup = function(opts)
  opts = opts or {}
  if opts.custom_path then
    state.dir = opts.custom_path
    state.quick_dir = opts.custom_path
  end

  if vim.fn.isdirectory(state.quick_dir) == 0 then
    vim.fn.mkdir(state.quick_dir, "p")
  end

  if opts.keys then
    for _, keymap in ipairs(opts.keys) do
      local mode, lhs, rhs, key_opts = unpack(keymap)
      vim.keymap.set(mode, lhs, rhs, key_opts)
    end
  end

  if opts.commands then
    for _, cmd in ipairs(opts.commands) do
      local command, method, cmd_opts = unpack(cmd)
      create_command(command, method, cmd_opts)
    end
  else
    create_command("Quicknote", M.quick_note, {})
    create_command("QuicknoteList", M.quick_note_list, {})
    create_command("QuicknoteNew", M.quick_note_new, {})
    create_command("QuicknoteDelete", M.quick_note_delete, {})
  end
end

return M
