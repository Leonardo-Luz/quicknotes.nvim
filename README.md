## quicknotes.nvim

*A Neovim Plugin for Quick Note-Taking*

### **Features:**

* Easy note creation and opening in a designated directory.
* Integrated save and rename functionality.
* notes are saved in `.local/share/nvim/quicknotes`

### **Dependencies:**

* `leonardo-luz/floatwindow.nvim`
* `nvim-lua/plenary.nvim`

### **Installation:** 

* Add `leonardo-luz/quicknotes.nvim` to your Neovim plugin manager (e.g., `init.lua` or `plugins/quicknotes.lua`).

```lua
{
    'leonardo-luz/quicknotes.nvim',
    custom_path = "/home/USER/PATH/TO/NOTES", # OPTIONAL, default goes to data path (in Linux: /home/user/.local/share/nvim/quicknotes)
    keys = {
        { 'n', '<leader>nn', '<cmd>QuicknoteNew<cr>',    { desc = "Quick [N]ote [N]ew " } },
        { 'n', '<leader>np', '<cmd>Quicknote<cr>',       { desc = "Quick [N]ote [P]revious" } },
        { 'n', '<leader>nd', '<cmd>QuicknoteDelete<cr>', { desc = "Quick [N]ote [D]elete List" } },
        { 'n', '<leader>nl', '<cmd>QuicknoteList<cr>',   { desc = "Quick [N]ote [L]ist" } },
    }
}
```

### **Usage:**

**Commands**

* `:QuickNote`: Opens the last opened note, or creates a new one if none exists.
* `:QuickNoteNew`: Creates a new note.
* `:QuickNoteList`: Lists available notes for editing.
* `:QuickNoteDelete`: Lists available notes for deletion.

**Keymaps**

* `<Esc><Esc>`: Closes the current note.
