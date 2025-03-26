local floatwindow = require("floatwindow")

local Path = require("plenary.path")

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
  quick_dir = vim.fn.stdpath("data") .. "/quicknotes",
  data_file = Path:new(vim.fn.stdpath("data") .. "/quicknotes", "notes.json"),
}

local clear_remaps
local remaps

local function new_note_path(filename)
  return Path:new(state.quick_dir, filename)
end

--- read the note file
local function read_note(filename)
  local note_file = new_note_path(filename)

  local file_content = {}

  if note_file:exists() then
    file_content = note_file:readlines()
  end

  return file_content
end

--- write in the note file
local function write_note(filename, data)
  local note_file = Path:new(state.quick_dir, filename)

  note_file:write(data, "w")
end

--- read the data file
local function read_data()
  if state.data_file:exists() then
    local file_content = state.data_file:read()
    return vim.json.decode(file_content)
  else
    return {}
  end
end

--- write in the file data file
local function write_data(data)
  state.data_file:write(vim.json.encode(data), "w")
end

local function insert_data(filename)
  local data = read_data()

  for key, data_name in pairs(data) do
    if data_name == filename then
      table.remove(data, key)
      break;
    end
  end

  table.insert(data, 1, filename)

  write_data(data)
end

local function remove_data(filename)
  local data = read_data()

  for key, data_name in pairs(data) do
    if data_name == filename then
      table.remove(data, key)
    end
  end

  write_data(data)
end

--- get all the notes
local function all_notes()
  state.notes = {}
  local file = read_data()
  if file then
    state.notes = file
  else
    vim.print("Error opening data file: " .. state.data_file)
  end
end

--- get the last opened note
local function get_last_note()
  all_notes()
  if #state.notes > 0 then
    return state.notes[1]
  else
    return nil
  end
end


--- extracts the first markdown header as the file name
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

local function get_current_note_lines()
  return vim.api.nvim_buf_get_lines(state.window_config.floating.buf, 0, -1, false)
end

--- save current note
local function save()
  local new_filename = get_header()
  local old_filename = state.cur_filename

  if new_filename == nil then
    vim.print("No title found in buffer")
    return
  end

  local data = state.notes

  local rename_id = nil
  for key, note in pairs(data) do
    if old_filename ~= new_filename and old_filename == note then
      rename_id = key
    end
  end

  if rename_id then
    local renamed_file = table.remove(data, rename_id)
    remove_data(renamed_file)

    local old_file_path = new_note_path(renamed_file)

    if old_file_path:exists() then
      old_file_path:rename({
        new_name = state.quick_dir .. "/" .. new_filename
      })
    end
  end

  local lines = table.concat(get_current_note_lines(), "\n")
  write_note(new_filename, lines)

  insert_data(new_filename)
end

--- creates a new note
local create_note = function()
  all_notes()

  if vim.api.nvim_win_is_valid(state.window_config.floating.win) then
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end

  state.cur_filename = "Note-" .. os.date("%Y%m%d-%H%M%S")

  state.window_config.floating = floatwindow.create_floating_window(state.window_config)

  table.insert(state.notes, state.cur_filename)

  if remaps then
    remaps()
  end

  local header = { "# " .. state.cur_filename }
  vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, true, header)
  vim.bo[vim.api.nvim_get_current_buf()].filetype = "markdown"

  local lines = table.concat(header, "\n")
  write_note(state.cur_filename, lines)
  insert_data(state.cur_filename)
end

--- delete selected file and remove it from data file
local delete_note = function(filename)
  vim.ui.select({ "Yes", "No" }, {
    prompt = "Do you realy want to delete the note " .. filename,
  }, function(choice)
    if choice == "Yes" then
      local data = read_data()
      if #data == 0 then
        vim.print("Error opening file: " .. state.data_file)
        return
      end

      --- remove note from data file
      for key, note in ipairs(data) do
        if note == filename then
          table.remove(data, key)
          break
        end
      end
      write_data(data)

      local to_delete = state.quick_dir .. "/" .. filename
      vim.fn.delete(to_delete)
    elseif choice == "No" then
      vim.print("Note deletion cancelled")
    end
  end)
end

--- clear created keymaps
clear_remaps = function()
  if vim.api.nvim_buf_is_valid(state.window_config.floating.buf) then
    vim.keymap.del("n", "<esc><esc>", { buffer = state.window_config.floating.buf })
    vim.api.nvim_del_autocmd(state.save_cmd_id)
  end
end

--- create keymaps
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

--- open selected file and push it as first in the data file
local open_note = function(filename)
  for _, note in ipairs(state.notes) do
    if filename == note then
      state.cur_filename = filename

      if vim.api.nvim_win_is_valid(state.window_config.floating.win) then
        vim.api.nvim_win_close(state.window_config.floating.win, true)
      end

      state.window_config.floating = floatwindow.create_floating_window(state.window_config)
      if remaps then
        remaps()
      end

      local lines = read_note(filename)
      vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, false, lines)

      --- push selected note to first in data file
      local data = read_data()
      for key, note_data in pairs(data) do
        if note_data == filename then
          table.remove(data, key)
          break;
        end
      end
      table.insert(data, filename)

      vim.bo[vim.api.nvim_get_current_buf()].filetype = "markdown"
      return
    end
  end
end

--- opens last note or create a new one if none was found
local open_last_note = function()
  all_notes()
  state.cur_filename = get_last_note()

  if state.cur_filename == nil then
    create_note()
  else
    open_note(state.cur_filename)
  end
end


--- opens last opened note
M.quick_note = function()
  if not vim.api.nvim_win_is_valid(state.window_config.floating.win) then
    open_last_note()
  else
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end
end

--- create new note and open it
M.quick_note_new = function()
  create_note()
end

--- quick note open menu
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

    if choice == "+ New Note" then
      M.quick_note_new()
    else
      for _, note in ipairs(state.notes) do
        local striped_choice = choice:match("-%s(.*)")

        if striped_choice == note then
          open_note(striped_choice)
          return
        end
      end
    end
  end)
end

--- quick note delete menu
M.quick_note_delete = function()
  all_notes()

  local choices = {}
  for i, note in ipairs(state.notes) do
    table.insert(choices, i .. " - " .. note)
  end

  table.insert(choices, "X - Cancel")

  vim.ui.select(choices, {
    prompt = "Delete Note",
  }, function(choice)
    for _, note in ipairs(state.notes) do
      if choice == nil or choice == "X - Cancel" then
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
  opts = opts or {}

  if vim.fn.isdirectory(state.quick_dir) == 0 then
    vim.fn.mkdir(state.quick_dir, "p")
  end

  if opts.keys then
    for _, keymap in ipairs(opts.keys) do
      local mode, lhs, rhs, key_opts = unpack(keymap)
      vim.keymap.set(mode, lhs, rhs, key_opts)
    end
  end
end

return M
