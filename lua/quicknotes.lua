local floatwindow = require("floatwindow") -- Make sure floatwindow is installed!

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
  rename = "",
  data_file = "",
  notes = {},
}

local clean_remaps
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

local function check_last_note()
  all_notes()
  if #state.notes > 0 then
    return state.notes[#state.notes]
  else
    return nil
  end
end

local function save()
  local lines = vim.api.nvim_buf_get_lines(state.window_config.floating.buf, 0, -1, false)
  local filename = nil
  for _, line in ipairs(lines) do
    if line:match("^#+%s*(.*)%s*$") then --Improved regex
      filename = line:match("^#+%s*(.*)%s*$")
      break
    end
  end

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
  local rename = false
  for _, note in ipairs(state.notes) do
    if note == filename then
      found = true
    elseif filename ~= state.rename and note == state.rename then
      rename = true
    else
      file:write(note .. "\n")
    end
  end

  if not found then
    table.insert(state.notes, filename)
  end

  file:write(filename .. "\n")
  file:close()
  -- state.filename = filename
  if rename then
    vim.fn.rename(state.path .. "/" .. state.rename .. ".md", state.path .. "/" .. filename .. ".md")
  end

  vim.cmd(string.format("w! %s/%s.md", state.path, filename))
end

local create_note = function()
  state.filename = ""

  state.filename = "Note-" .. os.date("%Y%m%d-%H%M%S")
  state.rename = state.filename

  vim.cmd(string.format("edit! %s/%s.md", state.path, state.filename))
  state.window_config.floating.buf = vim.api.nvim_get_current_buf()

  table.insert(state.notes, state.filename)

  if remaps then
    remaps()
  end

  local header = { "# " .. state.filename }
  vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, true, header)
end

local function new_note()
  vim.ui.select({ "Yes", "No" }, {
    prompt = "Do you want to create a new note?",
  }, function(choice)
    if choice == "Yes" then
      if clean_remaps then
        clean_remaps()
      end

      create_note()
    elseif choice == "No" then
      vim.print("Note creation cancelled")
    else
      vim.print("Invalid choice.")
    end
  end)
end

local function next_note()
  save()

  local index = -1
  for i, note in ipairs(state.notes) do
    if note == state.filename then
      index = i
      break
    end
  end

  if index == -1 then -- Handle case where current note isn't found
    new_note()
    return
  end

  if index < #state.notes then
    state.filename = state.notes[index + 1]
    state.rename = state.filename
    vim.print(state.rename)
    if clean_remaps then
      clean_remaps()
    end
    vim.cmd(string.format("edit %s/%s.md", state.path, state.filename))
    state.window_config.floating.buf = vim.api.nvim_get_current_buf()
    if remaps then
      remaps()
    end
  else
    new_note()
    return
  end
end

local function prev_note()
  save()
  local index = -1
  for i, note in ipairs(state.notes) do
    if note == state.filename then
      index = i
      break
    end
  end

  if index <= 1 then
    return
  end

  state.filename = state.notes[index - 1]
  state.rename = state.filename

  if clean_remaps then
    clean_remaps()
  end
  vim.cmd(string.format("edit %s/%s.md", state.path, state.filename))
  state.window_config.floating.buf = vim.api.nvim_get_current_buf()
  if remaps then
    remaps()
  end
end

local open_last_note = function()
  all_notes()
  state.filename = check_last_note()
  state.rename = state.filename

  if state.filename == nil then
    create_note()
  else
    vim.cmd(string.format("edit! %s/%s.md", state.path, state.filename))
    state.window_config.floating.buf = vim.api.nvim_get_current_buf()
    remaps()
  end
end

-- WIP
local delete_current_note = function()
  vim.ui.select({ "Yes", "No" }, {
    prompt = "Do you realy want to delete the current note?",
  }, function(choice)
    if choice == "Yes" then
      if clean_remaps then
        clean_remaps()
      end

      local file = io.open(state.data_file, "w+")
      if not file then
        vim.api.nvim_err_writeln("Error opening file: " .. state.data_file)
        return
      end

      for _, note in ipairs(state.notes) do
        if note ~= state.filename then
          file:write(note .. "\n")
        end
      end

      file:close()

      local to_delete = state.path .. "/" .. state.filename .. ".md"
      vim.fn.delete(to_delete)

      open_last_note()
    elseif choice == "No" then
      vim.print("Note deletion cancelled")
    else
      vim.print("Invalid choice.")
    end
  end)
end

clean_remaps = function()
  vim.keymap.del("n", "<Esc><Esc>", { buffer = state.window_config.floating.buf })
  vim.keymap.del("n", "n", { buffer = state.window_config.floating.buf })
  vim.keymap.del("n", "p", { buffer = state.window_config.floating.buf })
  vim.keymap.del("n", "<leader>d", { buffer = state.window_config.floating.buf })
end

remaps = function()
  vim.keymap.set("n", "<Esc><Esc>", function()
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end, { buffer = state.window_config.floating.buf })

  vim.keymap.set("n", "n", function()
    next_note()
  end, { buffer = state.window_config.floating.buf })

  vim.keymap.set("n", "p", function()
    prev_note()
  end, { buffer = state.window_config.floating.buf })

  vim.keymap.set("n", "<leader>d", function()
    delete_current_note()
  end, { buffer = state.window_config.floating.buf })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.window_config.floating.buf,
    callback = function()
      save()
    end,
  })
end

M.quick_note = function()
  state.window_config.floating.buf = -1

  state.window_config.floating = floatwindow.create_floating_window(state.window_config)

  open_last_note()
end

vim.api.nvim_create_user_command("Quicknote", M.quick_note, {})

M.setup = function(opts)
  state.path = opts.path or vim.fn.expand("%:p:h") --Default to current dir
  state.data_file = string.format("%s/my-notes.txt", state.path)
end

return M
