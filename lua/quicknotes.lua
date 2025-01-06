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
  filename = "Note-" .. os.time(),
  rename = nil,
  data_file = "",
  notes = {},
}

local check_last_note = function()
  state.notes = {}

  vim.print(state.data_file)

  local file = io.open(state.data_file, "a+")

  if file == nil then
    file = io.open(state.data_file, "w+")

    if file == nil then
      vim.print("Error openning data file")
      return
    end
  end

  local filename = nil

  for line in file:lines() do
    if not string.match(line, "^ *$") then
      table.insert(state.notes, line)
      filename = line
    end
  end

  return filename
end

local save = function()
  local check_file = check_last_note()

  local lines = vim.api.nvim_buf_get_lines(state.window_config.floating.buf, 0, -1, false)
  local filename = nil

  -- Verifies if theres an title inside the buffer
  for _, line in ipairs(lines) do
    if line:find("^#") then
      -- Saves title as the file name removing all `#` chars and whitespaces
      filename = line:match("^#+%s*(.*)%s*$")
      print(filename)
      break
    end
  end

  if filename == nil then
    vim.api.nvim_err_writeln("No title found in buffer")
    return
  end

  if check_file ~= filename then
    local file = io.open(state.data_file, "r")
    if file == nil then
      vim.api.nvim_err_writeln("Error opening file: " .. state.data_file)
      return
    end

    local aux_lines = {}
    for line in file:lines() do
      if line ~= filename then
        table.insert(aux_lines, line)
      end
    end
    io.close(file)

    file = io.open(state.data_file, "w+")
    if file == nil then
      vim.api.nvim_err_writeln("Error opening file: " .. state.data_file)
      return
    end

    for _, line in ipairs(aux_lines) do
      file:write(line .. "\n")
    end

    file:write(filename .. "\n")

    io.close(file)
  end

  vim.cmd(string.format("w %s/%s.md", state.path, filename))
end

M.quick_note = function()
  -- state.window_config.floating = {
  --   buf = -1,
  --   win = -1,
  -- }

  state.filename = check_last_note()

  state.window_config.floating = floatwindow.create_floating_window(state.window_config)

  if state.filename == nil then
    state.filename = "Note-" .. os.time()
    local header = { "-- Change header for your file name", "# " .. state.filename }

    vim.api.nvim_buf_set_lines(state.window_config.floating.buf, 0, -1, true, header)
  end

  vim.print(string.format("Current note - %s", state.filename))

  vim.cmd(string.format("edit %s/%s.md", state.path, state.filename))

  vim.keymap.set("n", "<esc><esc>", function()
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end, {
    buffer = state.window_config.floating.buf,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.window_config.floating.buf,
    callback = function()
      save()
    end,
  })
end

vim.api.nvim_create_user_command("Quicknote", M.quick_note, {})

---@class quicknotes.Setup
---@field path string: String to where the notes will be saved

---setup quicknotes plugin
---@param opts quicknotes.Setup
M.setup = function(opts)
  state.path = opts.path
  state.data_file = string.format("%s/my-notes.txt", opts.path)
end

return M
