---@diagnostic disable: no-unknown
local smartcolumn = {}

local config = {
    colorcolumn = 80,
    custom = {},
    disabled_filetypes = { "markdown" },
    editorconfig = true,
}

local disabled = true

---@type (number|number[]|nil)
local colorcolumns = nil

---@type number
local colorcolumns_first = nil

---@type string
local colorcolumns_string = nil

local function colorcolumn_recompute(_ev)
    disabled = vim.bo.buftype ~= "" -- special buffers
        or vim.bo.filetype == "" -- no filetype
        or vim.tbl_contains(config.disabled_filetypes, vim.bo.filetype) -- disabled filetypes

    if disabled then
        return
    end

    colorcolumns = config.editorconfig
        and vim.b[0].editorconfig
        and tonumber(vim.b[0].editorconfig.max_line_length)

    -- If the filetype is gitcommit, we don't want to use the editorconfig
    if colorcolumns == nil or vim.bo.ft == "gitcommit" then
        colorcolumns = config.custom[vim.bo.ft]
            or colorcolumns
            or config.colorcolumn
    end

    if type(colorcolumns) == "table" then
        colorcolumns_first = colorcolumns[1]
    else
        colorcolumns_first = colorcolumns
    end

    if type(colorcolumns) == "table" then
        colorcolumns_string = table.concat(colorcolumns, ",")
    else
        colorcolumns_string = tostring(colorcolumns)
    end
end

local function should_display(buf, win)
    local lines = vim.api.nvim_buf_get_lines(
        buf,
        vim.fn.line("w0", win) - 1,
        vim.fn.line("w$", win),
        true
    )

    local max_column = 0
    for _, line in pairs(lines) do
        local ok, column_number = pcall(vim.fn.strdisplaywidth, line)

        if not ok then
            return false
        end

        max_column = math.max(max_column, column_number)
    end

    return max_column > colorcolumns_first
end

local function colorcolumn_refresh(_ev)
    if disabled then
        return
    end

    local current_buf = vim.api.nvim_get_current_buf()
    local wins = vim.api.nvim_list_wins()
    for _, win in pairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if buf == current_buf then
            local display = should_display(buf, win)
            local current_cc = vim.wo[win].colorcolumn
            if display and current_cc == "" then
                vim.wo[win].colorcolumn = colorcolumns_string
            elseif not display and current_cc ~= "" then
                vim.wo[win].colorcolumn = ""
            end
        end
    end
end

function smartcolumn.setup(user_config)
    user_config = user_config or {}

    for option, value in pairs(user_config) do
        config[option] = value
    end

    -- New created window will inherit the colorcolumn from the current window,
    -- so we need to clear it.
    vim.api.nvim_create_autocmd({ "WinNew" }, {
        group = vim.api.nvim_create_augroup(
            "SmartColumnClear",
            { clear = false }
        ),
        callback = function()
            vim.wo.colorcolumn = ""
        end,
    })

    -- Recompute the colorcolumn string when a buffer is entered
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = vim.api.nvim_create_augroup(
            "SmartColumnRecompute",
            { clear = true }
        ),
        callback = colorcolumn_recompute,
    })

    -- Refresh the colorcolumn when the cursor moves
    vim.api.nvim_create_autocmd(
        { "CursorMoved", "CursorMovedI", "WinScrolled" },
        {
            group = vim.api.nvim_create_augroup(
                "SmartColumnRefresh",
                { clear = true }
            ),
            callback = colorcolumn_refresh,
        }
    )
end

return smartcolumn
