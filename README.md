## quicknotes.nvim

*A Neovim Plugin for Quick Note-Taking*

**Features:**

* Create and open notes quickly and easily in a specified directory.

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

* `:QuickNote`: Opens your last note or creates a new one if none was found.
    * `n`: Go to the next note, if none was found creates a new one.
    * `p`: Go to the previous note.
    * `<leader>d`: Delete current note
