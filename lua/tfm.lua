local PATH_CACHE = vim.fn.stdpath("cache")
local PATH_SELECTED_FILES = PATH_CACHE .. "/tfm_selected_files"

local M = {}

---@class FileManager
---@field cmd string command name
---@field set_file_chooser_output string flag to set the chosen files output file
---@field set_focused_file string flag to set the focused file

---Configurable user options.
---@class Options
---@field file_manager string
---@field enable_cmds boolean
---@field replace_netrw boolean
---@field keybindings table<string, string>
---@field ui UI

---@class UI
---@field border string (see ':h nvim_open_win')
---@field height number from 0 to 1 (0 = 0% of screen and 1 = 100% of screen)
---@field width number from 0 to 1 (0 = 0% of screen and 1 = 100% of screen)
---@field x number from 0 to 1 (0 = left most of screen and 1 = right most of
---screen)
---@field y number from 0 to 1 (0 = top most of screen and 1 = bottom most of
---screen)

---@class WindowDimensions
---@field height number height of the window
---@field width number width of the window
---@field row number row from which to begin drawing window
---@field col number column from which to begin drawing window

---@enum OPEN_MODE
M.OPEN_MODE = {
    vsplit = "vsplit",
    split = "split",
    tabedit = "tabedit",
}

---@type table<FileManager>
M.FILE_MANAGERS = {
    ranger = {
        cmd = "ranger",
        set_file_chooser_output = "--choosefiles",
        set_focused_file = "--selectfile",
    },
    nnn = {
        cmd = "nnn",
        set_file_chooser_output = "-p",
        set_focused_file = "",
    },
    lf = {
        cmd = "lf",
        set_file_chooser_output = "-selection-path",
        set_focused_file = "",
    },
    yazi = {
        cmd = "yazi",
        set_file_chooser_output = "--chooser-file",
        set_focused_file = "",
    },
    vifm = {
        cmd = "vifm",
        set_file_chooser_output = "--choose-files",
        set_focused_file = "--select",
    },
}

---@type Options
local opts = {
    file_manager = "yazi",
    enable_cmds = false,
    replace_netrw = false,
    ui = {
        border = "rounded",
        height = 1,
        width = 1,
        x = 0.5,
        y = 0.5,
    },
    keybindings = {},
}

---Get the function which will be used to open files based on the given mode
---@param open_mode OPEN_MODE|nil The mode to open the selected file(s) with
---@return function
local function get_edit_fn(open_mode)
    if open_mode == nil or M.OPEN_MODE[open_mode] == nil then
        return vim.cmd.edit
    end

    local alternative_open_funcs = {
        vsplit = vim.cmd.vsplit,
        split = vim.cmd.split,
        tabedit = vim.cmd.tabedit,
    }

    return alternative_open_funcs[open_mode]
end

---Handles opening of the selected path(s)
---@param open_mode OPEN_MODE|nil The mode to open the selected file(s) with
local function open_paths(open_mode)
    if vim.fn.filereadable(PATH_SELECTED_FILES) ~= 1 then
        return
    end

    local selected_files = vim.fn.readfile(PATH_SELECTED_FILES)
    local edit = get_edit_fn(open_mode)
    local directories = {}

    for _, path in ipairs(selected_files) do
        if vim.fn.isdirectory(path) == 1 then
            table.insert(directories, path)
        else
            edit(path)
        end
    end

    -- Reopen the TFM again with the selected first directory, ignore the rest
    local _, first_dir = next(directories)
    if first_dir ~= nil then
        M.open(first_dir, open_mode)
    end
end

---Builds the TFM launch command
---@param selected_manager FileManager
---@param path_to_open string|nil Path to the file/directory to open. If `nil`, the current file will be used. If this is invalid, the `cwd` will be used as the fallback.
---@return string
local function build_tfm_cmd(selected_manager, path_to_open)
    -- FILE CHOOSER MODE
    local arg_file_chooser =
        string.format("%s %s", selected_manager.set_file_chooser_output, PATH_SELECTED_FILES)

    -- FILE TO BE FOCUSED
    -- Take the given path or fallback to the current file
    local file_to_focus
    if path_to_open == nil then
        -- If the current file is invalid, this will return `""` which should just open the `cwd`
        file_to_focus = vim.fn.expand("%")
    else
        file_to_focus = path_to_open
    end

    -- If there is a file path, quote it to avoid issues with spaces in file names
    if file_to_focus ~= "" then
        file_to_focus = string.format('"%s"', file_to_focus)
    end

    local arg_focus_file = string.format("%s %s", selected_manager.set_focused_file, file_to_focus)

    return string.format(
        "%s %s %s",
        selected_manager.cmd,
        arg_file_chooser,
        -- Must be last, as most TFMs just accept the filename to focus it, without requiring a specific flag
        arg_focus_file
    )
end

---Returns a table with the names of all the currently listed buffers, which point to existing filenames
---@return WindowDimensions
local function get_window_dimensions()
    local win_height = math.ceil(vim.o.lines * opts.ui.height)
    local win_width = math.ceil(vim.o.columns * opts.ui.width)
    return {
        height = win_height,
        width = win_width,
        row = math.ceil((vim.o.lines - win_height) * opts.ui.y - 1),
        col = math.ceil((vim.o.columns - win_width) * opts.ui.x),
    }
end

---Open a window for the TFM to run in
local function open_win()
    local buf = vim.api.nvim_create_buf(false, true)

    local win = vim.api.nvim_open_win(
        buf,
        true,
        vim.tbl_extend("error", {
            relative = "editor",
            border = opts.ui.border,
            style = "minimal",
        }, get_window_dimensions())
    )
    vim.api.nvim_set_option_value("winhl", "NormalFloat:Normal", { win = win })
    vim.api.nvim_set_option_value("filetype", "tfm", { buf = buf })

    -- Resize the window when the Neovim is resized
    local group = vim.api.nvim_create_augroup("tfm_window", { clear = true })
    vim.api.nvim_create_autocmd("VimResized", {
        group = group,
        buffer = buf,
        callback = function()
            vim.api.nvim_win_set_config(
                win,
                vim.tbl_deep_extend(
                    "force",
                    vim.api.nvim_win_get_config(win),
                    get_window_dimensions()
                )
            )
        end,
    })

    -- Apply custom keybinds
    for keybind, command in pairs(opts.keybindings) do
        vim.api.nvim_buf_set_keymap(buf, "t", keybind, command, { silent = true })
    end
end

---Returns a table with the names of all the currently listed buffers, which point to existing filenames
---@return table<string>
local function get_buffers_for_existing_files()
    local buffer_names = {}

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.fn.buflisted(buf) == 1 then
            local buf_name = vim.fn.bufname(buf)
            if vim.fn.filereadable(buf_name) == 1 then
                table.insert(buffer_names, buf_name)
            end
        end
    end

    return buffer_names
end

---Closes any buffers from the given table of buffer names which point to files that don't exist
---@param buffers table<string>
local function close_empty_buffers(buffers)
    for _, buf in ipairs(buffers) do
        if vim.fn.filereadable(buf) ~= 1 then
            vim.cmd.bdelete(buf)
        end
    end
end

---Clean up temporary files used to communicate between the terminal file manager and the plugin
local function clean_up()
    vim.fn.delete(PATH_SELECTED_FILES)
end

---Disable and replace netrw
local function replace_netrw()
    -- DISABLE NETRW
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    vim.g.loaded_netrwSettings = 1
    vim.g.loaded_netrwFileHandlers = 1
    pcall(vim.api.nvim_clear_autocmds, { group = "FileExplorer" })

    -- REPLACE ON STARTUP
    -- Launch the terminal file manager when entering `nvim` with a directory as the first argument
    vim.api.nvim_create_autocmd("VimEnter", {
        pattern = "*",
        callback = function()
            local path = vim.fn.argv(0)
            if vim.fn.isdirectory(path) == 1 then
                vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })
                M.open(path)
            end

            -- REPLACE FOR ANY OPENED FOLDER BUFFER
            -- Defined here so it doesn't fire when opening nvim with a directory
            -- Launch the terminal file manager when opening a buffer pointing to a directory (e.g. with :e path/to/dir/)
            vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
                callback = function()
                    local current_bufnr = vim.api.nvim_get_current_buf()
                    local buf_name = vim.api.nvim_buf_get_name(current_bufnr)

                    if vim.fn.isdirectory(buf_name) == 1 then
                        pcall(vim.api.nvim_buf_delete, current_bufnr, { force = true })
                        M.open(buf_name)
                    end
                end,
            })
        end,
    })
end

---Opens the terminal file manager and open selected files on exit
---@param path_to_open string|nil Open the terminal file manager and select the current file. False means open the current directory instead (or pass in a second argument to specify a different path). Defaults to true.
---@param open_mode OPEN_MODE|nil Open the selected file(s) using a specific mode, e.g. "split", "vsplit", "tabedit"
function M.open(path_to_open, open_mode)
    ---@type FileManager
    local selected_file_manager = M.FILE_MANAGERS[opts.file_manager]

    -- Set default TFM if selected option is invalid
    if not selected_file_manager then
        vim.notify(
            string.format(
                "The provided value of '%s' is not a supported terminal file manager",
                opts.file_manager
            ),
            vim.log.levels.ERROR
        )
        selected_file_manager = M.FILE_MANAGERS.yazi
    end

    -- Exit early if the selected TFM is not executable
    assert(
        vim.fn.executable(selected_file_manager.cmd) == 1,
        string.format(
            "The '%s' executable not found, please check that '%s' is installed and is in your path\n",
            selected_file_manager.cmd,
            selected_file_manager.cmd
        )
    )

    -- In case there are leftover files
    clean_up()

    -- Store buffers that are open (and not empty) prior to running the terminal file manager
    local buffers_for_existing_files = get_buffers_for_existing_files()

    local cmd = build_tfm_cmd(selected_file_manager, path_to_open)
    local last_win = vim.api.nvim_get_current_win()

    open_win()

    local on_exit = function(_, code, _)
        -- Return early if there was some error with the TFM
        if code ~= 0 then
            return
        end

        -- get buffer vars before closing the terminal window
        open_mode = vim.b.tfm_next_open_mode or open_mode

        vim.api.nvim_win_close(0, true)
        vim.api.nvim_set_current_win(last_win)

        open_paths(open_mode)

        clean_up()
        -- Close any buffers that were previously pointing to existing files, but don't
        -- after running the TFM. This should close any buffers for files which were
        -- deleted using the TFM.
        close_empty_buffers(buffers_for_existing_files)
    end

    if vim.fn.has("nvim-0.9") then
        ---@diagnostic disable-next-line: deprecated
        vim.fn.termopen(cmd, {
            on_exit = on_exit,
        })
    else
        vim.fn.jobstart(cmd, {
            term = true,
            on_exit = on_exit,
        })
    end

    vim.cmd.startinsert()
end

---Change the current file manager
---@param file_manager string
M.select_file_manager = function(file_manager)
    assert(
        file_manager ~= "" and M.FILE_MANAGERS[file_manager] ~= nil,
        string.format("'%s' is not a valid option for a file_manager", file_manager)
    )

    opts.file_manager = file_manager
end

---Set the next mode that selected file(s) will be opened with
---@param open_mode OPEN_MODE|nil The next mode to open selected file(s) with
function M.set_next_open_mode(open_mode)
    vim.b.tfm_next_open_mode = open_mode
end

---Optional setup to configure tfm.nvim.
---@param user_opts Options|nil Configurable options.
function M.setup(user_opts)
    if user_opts then
        opts = vim.tbl_deep_extend("force", opts, user_opts)
    end

    if opts.replace_netrw then
        replace_netrw()
    end

    if opts.enable_cmds then
        vim.cmd('command! Tfm lua require("tfm").open()')
        vim.cmd(
            string.format('command! TfmSplit lua require("tfm").open(nil, "%s")', M.OPEN_MODE.split)
        )
        vim.cmd(
            string.format(
                'command! TfmVsplit lua require("tfm").open(nil, "%s")',
                M.OPEN_MODE.vsplit
            )
        )
        vim.cmd(
            string.format(
                'command! TfmTabedit lua require("tfm").open(nil, "%s")',
                M.OPEN_MODE.tabedit
            )
        )
    end
end

return M
