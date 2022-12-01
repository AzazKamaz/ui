local M = {}
local api = vim.api
local fn = vim.fn

loadfile(vim.g.base46_cache .. "nvdash")()

local config = require("core.utils").load_config().ui.nvdash

local headerAscii = config.header
local emmptyLine = string.rep(" ", vim.fn.strwidth(headerAscii[1]))

table.insert(headerAscii, 1, emmptyLine)
table.insert(headerAscii, 2, emmptyLine)

headerAscii[#headerAscii + 1] = emmptyLine
headerAscii[#headerAscii + 1] = emmptyLine

api.nvim_create_autocmd("BufWinLeave", {
  callback = function()
    if vim.bo.ft == "nvdash" then
      vim.g.nvdash_displayed = false
    end
  end,
})

local max_height = #headerAscii + 4 + (2 * #config.buttons) -- 4  = extra spaces i.e top/bottom
local get_win_height = api.nvim_win_get_height

M.open = function(buf, win)
  if vim.fn.expand "%" == "" or buf then
    if get_win_height(win) < max_height then
      return
    end

    buf = buf or api.nvim_create_buf(false, true)
    api.nvim_win_set_buf(win, buf)

    vim.g.nvdash_displayed = true

    local header = headerAscii
    local buttons = config.buttons

    local function addSpacing_toBtns(txt1, txt2)
      local btn_len = fn.strwidth(txt1) + fn.strwidth(txt2)
      local spacing = fn.strwidth(header[1]) - btn_len
      return txt1 .. string.rep(" ", spacing - 1) .. txt2 .. " "
    end

    local function addPadding_toHeader(str)
      local pad = (api.nvim_win_get_width(win) - fn.strwidth(str)) / 2
      return string.rep(" ", math.floor(pad)) .. str .. " "
    end

    local dashboard = {}

    for _, val in ipairs(header) do
      table.insert(dashboard, val .. " ")
    end

    for _, val in ipairs(buttons) do
      table.insert(dashboard, addSpacing_toBtns(val[1], val[2]) .. " ")
      table.insert(dashboard, header[1] .. " ")
    end

    local result = {}

    -- make all lines available
    for i = 1, get_win_height(win) do
      result[i] = ""
    end

    local headerStart_Index = math.floor((get_win_height(win) / 2) - (#dashboard / 2))
    local abc = math.floor((get_win_height(win) / 2) - (#dashboard / 2))

    -- set ascii
    for _, val in ipairs(dashboard) do
      result[headerStart_Index] = addPadding_toHeader(val)
      headerStart_Index = headerStart_Index + 1
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, result)

    local nvdash = api.nvim_create_namespace "nvdash"
    local horiz_pad_index = math.floor((api.nvim_win_get_width(win) / 2) - (36 / 2)) - 2

    for i = abc, abc + #header - 2 do
      api.nvim_buf_add_highlight(buf, nvdash, "NvDashAscii", i, horiz_pad_index, -1)
    end

    for i = abc + #header - 2, abc + #dashboard do
      api.nvim_buf_add_highlight(buf, nvdash, "NvDashButtons", i, horiz_pad_index, -1)
    end

    api.nvim_win_set_cursor(win, { abc + #header, math.floor(vim.o.columns / 2) - 13 })

    local first_btn_line = abc + #header + 2
    local keybind_lineNrs = {}

    for _, _ in ipairs(config.buttons) do
      table.insert(keybind_lineNrs, first_btn_line - 2)
      first_btn_line = first_btn_line + 2
    end

    vim.keymap.set("n", "h", "", { buffer = true })
    vim.keymap.set("n", "l", "", { buffer = true })

    vim.keymap.set("n", "k", function()
      local cur = fn.line "."
      local target_line = vim.tbl_contains(keybind_lineNrs, cur) and cur - 2 or keybind_lineNrs[#keybind_lineNrs]
      api.nvim_win_set_cursor(0, { target_line, math.floor(vim.o.columns / 2) - 13 })
    end, { buffer = true })

    vim.keymap.set("n", "j", function()
      local cur = fn.line "."
      local target_line = vim.tbl_contains(keybind_lineNrs, cur) and cur + 2 or keybind_lineNrs[1]
      api.nvim_win_set_cursor(0, { target_line, math.floor(vim.o.columns / 2) - 13 })
    end, { buffer = true })

    -- pressing enter on
    vim.keymap.set("n", "<CR>", function()
      for i, val in ipairs(keybind_lineNrs) do
        if val == fn.line "." then
          local action = config.buttons[i][3]

          if type(action) == "string" then
            vim.cmd(action)
          elseif type(action) == "function" then
            action()
          end
        end
      end
    end, { buffer = true })

    -- dont go to nvdash buffer if its already displayed in window
    if not vim.g.nvdash_displayed then
      api.nvim_set_current_buf(buf)
    end

    -- buf only options
    vim.opt_local.bufhidden = "wipe"
    vim.opt_local.modifiable = false
    vim.opt_local.filetype = "nvdash"
    vim.opt_local.buflisted = true
    vim.opt_local.wrap = false
    vim.opt_local.foldlevel = 999
    vim.opt_local.foldcolumn = "0"
    vim.opt_local.cursorcolumn = false
    vim.opt_local.cursorline = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.list = false
    vim.opt_local.spell = false
  end
end

local win = api.nvim_get_current_win()

-- redraw dashboard on VimResized event
vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    if vim.bo.filetype == "nvdash" then
      require("nvchad_ui.nvdash").open(false, win)
    end
  end,
})

-- testing!
local new_cmd = vim.api.nvim_create_user_command

local function redraw()
  for _, winnr in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = (vim.api.nvim_win_get_buf(winnr))

    if vim.bo[bufnr].ft == "nvdash" then
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "" })

      require("nvchad_ui.nvdash").open(bufnr, winnr)
      vim.notify "nvdash redrawed"
      break
    end
  end
end

new_cmd("Redraw", function()
  redraw()
end, {})

-- resize nvdash whenever opening & closing buffers { "WinClosed", "BufLeave", "WinEnter" }
vim.api.nvim_create_autocmd({ "WinNew" }, {
  callback = function()
    redraw()
  end,
})

return M
