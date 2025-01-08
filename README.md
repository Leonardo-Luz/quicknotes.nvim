## quicknotes.nvim

*A Neovim Plugin for Quick Note-Taking*

**Features:**

* Easy note creation and opening in a designated directory.
* Integrated save and rename functionality.

**Dependencies:**

* `leonardo-luz/floatwindow`

**Installation:**  Add `leonardo-luz/quicknotes.nvim` to your Neovim plugin manager (e.g., `init.lua` or `plugins/quicknotes.lua`).

```lua
{ 
    'leonardo-luz/quicknotes.nvim',
    opts = {
        path = '/path/to/your/notes/directory'  -- Replace with your desired path
    },
}
```

**Usage:**

* `:QuickNote`: Opens the last opened note, or creates a new one if none exists.
* `:QuickNoteNew`: Creates a new note.
* `:QuickNoteList`: Lists available notes for editing.
* `:QuickNoteDelete`: Lists available notes for deletion.

**Keymaps**

* `<Esc><Esc>`: Closes the current note.
