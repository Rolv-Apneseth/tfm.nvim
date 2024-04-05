# tfm.nvim

Neovim plugin for **T**erminal **F**ile **M**anager integration.

<details>
<summary><strong>Supported Terminal File Managers</strong></summary>

- [yazi](https://github.com/sxyazi/yazi)
- [ranger](https://github.com/ranger/ranger)
- [nnn](https://github.com/jarun/nnn)
- [lf](https://github.com/gokcehan/lf)
- [vifm](https://github.com/vifm/vifm)

</details>

[Demo video](https://github.com/Rolv-Apneseth/tfm.nvim/assets/69486699/360ef477-fe97-4e47-b3a9-7813c3f82198)

## Introduction

When I discovered [ranger.nvim](https://github.com/kelly-lin/ranger.nvim), it ended up replacing [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua) for me, which was great. My only issue was that I wasn't such a huge fan of `ranger` itself. In trying to find an alternative, I was having to switch plugins entirely for each new one I wanted to try out, which was not ideal and inspired me to create this.

With this plugin, you can simply change which TFM you wish to use (from the supported ones) in your configuration and you're good to go. It should also allow you to replace `netrw`.

I am using this plugin full time but I don't use all the different file managers and modes available so if you find any issues please let me know and I'll do my best to address it.

## Optional Dependencies

- [ueberzugpp](https://github.com/jstkdng/ueberzugpp): for previewing images. Requires that your chosen file manager supports it.

## Configuration

The setup function is completely optional. However, please note that by default this plugin does not set any keymaps or create any commands, so it is recommended to do so in your configuration.

The below example configurations are given for [lazy.nvim](https://github.com/folke/lazy.nvim) but feel free to use your desired plugin manager.

### Minimal

```lua
{
    "rolv-apneseth/tfm.nvim",
    config = function()
        -- Set keymap so you can open the default terminal file manager (yazi)
        vim.api.nvim_set_keymap("n", "<leader>e", "", {
            noremap = true,
            callback = require("tfm").open,
        })
    end,
}
```

### Full

```lua
{
    "rolv-apneseth/tfm.nvim",
    lazy = false,
    opts = {
        -- TFM to use
        -- Possible choices: "ranger" | "nnn" | "lf" | "vifm" | "yazi" (default)
        file_manager = "yazi",
        -- Replace netrw entirely
        -- Default: false
        replace_netrw = true,
        -- Enable creation of commands
        -- Default: false
        -- Commands:
        --   Tfm: selected file(s) will be opened in the current window
        --   TfmSplit: selected file(s) will be opened in a horizontal split
        --   TfmVsplit: selected file(s) will be opened in a vertical split
        --   TfmTabedit: selected file(s) will be opened in a new tab page
        enable_cmds = false, 
        -- Custom keybindings only applied within the TFM buffer
        -- Default: {}
        keybindings = {
            ["<ESC>"] = "q",
            -- override the open mode (i.e. vertical/horizontal split, new tab)
            -- and open the selected files
            ["<C-v>"] = "<C-\\><C-O>:lua require('tfm').next_open_mode(require('tfm').OPEN_MODE.vsplit)<CR><CR>",
            ["<C-x>"] = "<C-\\><C-O>:lua require('tfm').next_open_mode(require('tfm').OPEN_MODE.split)<CR><CR>",
            ["<C-t>"] = "<C-\\><C-O>:lua require('tfm').next_open_mode(require('tfm').OPEN_MODE.tabedit)<CR><CR>",
        },
        -- Customise UI. The below options are the default
        ui = {
            border = "rounded",
            height = 1,
            width = 1,
            x = 0.5,
            y = 0.5,
        },
    },
    keys = {
        -- Make sure to change these keybindings to your preference,
        -- and remove the ones you won't use
        {
            "<leader>e",
            ":Tfm<CR>",
            desc = "TFM",
        },
        {
            "<leader>mh",
            ":TfmSplit<CR>",
            desc = "TFM - horizontal split",
        },
        {
            "<leader>mv",
            ":TfmVsplit<CR>",
            desc = "TFM - vertical split",
        },
        {
            "<leader>mt",
            ":TfmTabedit<CR>",
            desc = "TFM - new tab",
        },
    },
}
```

### Configuration - UI

| Key | Type | Default | Value |
| --- | ---- | ------- | ----- |
| `border` | `string` | `"none"` | See `:h nvim_open_win`. |
| `height` | `number` | `1` | From 0 to 1 (0 = 0% of screen and 1 = 100% of screen). |
| `width` | `number` | `1` | From 0 to 1 (0 = 0% of screen and 1 = 100% of screen). |
| `x` | `number` | `0.5` | From 0 to 1 (0 = left most of screen and 1 = right most of screen). |
| `y` | `number` | `0.5` | From 0 to 1 (0 = top most of screen and 1 = bottom most of screen). |

## API

### `open()`

Opens the TFM, focusing the file from the current buffer, and falling back to the `CWD` if that is not possible.

### `open(path_to_open, open_mode)`

Opens the TFM at the given destination. If the path is a file, focuses that file. Selected file(s) will be
opened with the given mode.

- Setting `path_to_open` to `nil` is equivalent to calling `open()`
- `open_mode` should be an option from the enum defined below. Defaults to opening file(s) in the current window if an invalid option is received

### `select_file_manager(file_manager)`

Changes the selected file manager. This is not persistent so the change will be lost when restarting Neovim.

- `file_manager` should be one of the supported TFMs listed at the top of the page

### `enum OPEN_MODE`

Enum to configure modes with which to open/edit selected files.

| Variant | Action |
| ------- | ------ |
| `vsplit` | Open files in vertical split |
| `split` | Open files in horizontal split |
| `tabedit` | Open files in tab |

## Extras

### Pure Lua keybindings

If you don't want to enable the commands, you can just use pure Lua keybindings:

```lua
    keys = {
        {
            "<leader>e",
            function()
                require("tfm").open()
            end,
            desc = "TFM",
        },
        {
            "<leader>mh",
            function()
                local tfm = require("tfm")
                tfm.open(nil, tfm.OPEN_MODE.split)
            end,
            desc = "TFM - horizontal split",
        },
        {
            "<leader>mv",
            function()
                local tfm = require("tfm")
                tfm.open(nil, tfm.OPEN_MODE.vsplit)
            end,
            desc = "TFM - vertical split",
        },
        {
            "<leader>mt",
            function()
                local tfm = require("tfm")
                tfm.open(nil, tfm.OPEN_MODE.tabedit)
            end,
            desc = "TFM - new tab",
        },
    },
```

### Keybind to switch file manager

```lua
{
    "<leader>mc",
    function()
        local tfm = require("tfm")
        local selected_tfm = vim.fn.input("Change file manager: ")

        if selected_tfm ~= "" and tfm.FILE_MANAGERS[selected_tfm] ~= nil then
            tfm.select_file_manager(selected_tfm)
        end
    end,
    desc = "TFM - change selected file manager",
},
```

## Contributing

Feel free let me know how I can improve this plugin by opening an issue. PRs are also welcome.

## Credit

- [@kelly-lin](https://github.com/kelly-lin) for writing [ranger.nvim](https://github.com/kelly-lin/ranger.nvim)

### Other similar plugins

- [yazi.nvim](https://github.com/DreamMaoMao/yazi.nvim)
- [nnn.nvim](https://github.com/luukvbaal/nnn.nvim)
- [lf.nvim](https://github.com/lmburns/lf.nvim)
- [rnvimr](https://github.com/kevinhwang91/rnvimr) - for `ranger` as well, but actually uses `RPC` to communicate with it so it seems a good deal more complex than other similar plugins
- [fm-nvim](https://github.com/is0n/fm-nvim) - Very similar to this plugin, probably wish I had found this sooner lol. Unfortunately it does not seem to be actively maintained, and does not do some of the things I really wanted this to do, namely close buffers for files that were deleted and completely replace netrw. Also `yazi` is my favourite so far and that is unsupported.
