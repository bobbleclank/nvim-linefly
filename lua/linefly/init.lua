local git = require("linefly.git")
local plugins = require("linefly.plugins")
local utils = require("linefly.utils")
local buf_get_option = vim.api.nvim_buf_get_option
local fnamemodify = vim.fn.fnamemodify
local g = vim.g
local getcwd = vim.fn.getcwd
local mode = vim.api.nvim_get_mode
local opt = vim.opt
local opt_local = vim.opt_local
local pathshorten = vim.fn.pathshorten
local tabpagenr = vim.fn.tabpagenr
local winheight = vim.api.nvim_win_get_height

-- Refer to ':help mode()' for the full list of available modes. For now only
-- handle the most common modes.
local modes_map = {
  ["n"] = { "%#LineflyNormal#", " normal ", "%#LineflyNormalEmphasis#" }, -- Normal
  ["no"] = { "%#LineflyNormal#", " o-pend ", "%#LineflyNormalEmphasis#" }, -- Operator pending
  ["niI"] = { "%#LineflyNormal#", " i-pend ", "%#LineflyNormalEmphasis#" }, -- Insert mode pending (Ctrl-o)
  ["niR"] = { "%#LineflyNormal#", " r-pend ", "%#LineflyNormalEmphasis#" }, -- Replace mode pending (Ctrl-o)
  ["i"] = { "%#LineflyInsert#", " insert ", "%#LineflyInsertEmphasis#" }, -- Insert
  ["ic"] = { "%#LineflyInsert#", " i-comp ", "%#LineflyInsertEmphasis#" }, -- Insert completion (generic)
  ["ix"] = { "%#LineflyInsert#", " i-comp ", "%#LineflyInsertEmphasis#" }, -- Insert completion (Ctrl-x)
  ["v"] = { "%#LineflyVisual#", " visual ", "%#LineflyVisualEmphasis#" }, -- Visual (v)
  ["vs"] = { "%#LineflyVisual#", " visual ", "%#LineflyVisualEmphasis#" }, -- Visual (Ctrl-o select mode)
  ["V"] = { "%#LineflyVisual#", " v-line ", "%#LineflyVisualEmphasis#" }, -- Visual line (V)
  ["Vs"] = { "%#LineflyVisual#", " v-line ", "%#LineflyVisualEmphasis#" }, -- Visual line (Ctrl-o select mode)
  ["\022"] = { "%#LineflyVisual#", " v-bloc ", "%#LineflyVisualEmphasis#" }, -- Visual block (Ctrl-v)
  ["s"] = { "%#LineflyVisual#", " select ", "%#LineflyVisualEmphasis#" }, -- Select (gh)
  ["S"] = { "%#LineflyVisual#", " s-line ", "%#LineflyVisualEmphasis#" }, -- Select line (gH)
  ["\019"] = { "%#LineflyVisual#", " s-bloc ", "%#LineflyVisualEmphasis#" }, -- Select block (CTRL-S)
  ["c"] = { "%#LineflyCommand#", " c-mode ", "%#LineflyCommandEmphasis#" }, -- Command line
  ["r"] = { "%#LineflyCommand#", " prompt ", "%#LineflyReplaceEmphasis#" }, -- Prompt for 'enter'
  ["rm"] = { "%#LineflyCommand#", " prompt ", "%#LineflyReplaceEmphasis#" }, -- Prompt for 'more'
  ["r?"] = { "%#LineflyCommand#", " prompt ", "%#LineflyReplaceEmphasis#" }, -- Prompt for 'confirmation'
  ["!"] = { "%#LineflyCommand#", "  !-mode ", "%#LineflyReplaceEmphasis#" }, -- Command execution
  ["R"] = { "%#LineflyReplace#", " r-mode ", "%#LineflyReplaceEmphasis#" }, -- Replace
  ["Rc"] = { "%#LineflyReplace#", " r-comp ", "%#LineflyReplaceEmphasis#" }, -- Replace completion (generic)
  ["Rx"] = { "%#LineflyReplace#", " r-comp ", "%#LineflyReplaceEmphasis#" }, -- Replace completion (Ctrl-x)
  ["t"] = { "%#LineflyInsert#", " t-mode ", "%#LineflyInsertEmphasis#" }, -- Terminal
  ["nt"] = { "%#LineflyNormal#", " normal ", "%#LineflyNormalEmphasis#" }, -- Terminal normal mode
}

local M = {}

_G.linefly = M

------------------------------------------------------------
-- Status line
------------------------------------------------------------

M.active_statusline = function()
  local current_mode = mode().mode
  local divider = g.lineflyAsciiShapes and "|" or "⎪"
  local arrow = g.lineflyAsciiShape and "" or "↓"
  local branch_name = git.current_branch_name()
  local mode_emphasis = modes_map[current_mode][3]

  local statusline = modes_map[current_mode][1]
  statusline = statusline .. modes_map[current_mode][2]
  statusline = statusline .. "%* %<" .. utils.filename()
  statusline = statusline .. "%{&modified ? '+ ' : '  '}"
  statusline = statusline .. "%{&readonly ? 'RO ' : ''}"
  if not utils.is_empty(branch_name) then
    statusline = statusline .. "%*" .. divider .. mode_emphasis
    statusline = statusline .. branch_name .. "%* "
  end
  statusline = statusline .. plugins.status()
  statusline = statusline .. "%*%=%l:%c %*" .. divider
  statusline = statusline .. "%* " .. mode_emphasis .. "%L%* " .. arrow .. "%P "
  if g.lineflyWithIndentStatus then
    statusline = statusline .. "%*" .. divider .. "%* %{linefly#IndentStatus()} " -- XXX port to Lua
  end

  return statusline
end

M.inactive_statusline = function()
  local divider = g.lineflyAsciiShapes and "|" or "⎪"
  local arrow = g.lineflyAsciiShape and "" or "↓"

  local statusline = " %*%<" .. utils.filename()
  statusline = statusline .. "%{&modified?'+ ':'  '}"
  statusline = statusline .. "%{&readonly?'RO ':''}"
  statusline = statusline .. "%*%=%l:%c " .. divider .. " %L " .. arrow .. "%P "
  if g.lineflyWithIndentStatus then
    statusline = statusline .. divider .. " %{linefly#IndentStatus()} " -- XXX port to Lua
  end

  return statusline
end

M.statusline = function(active)
  if buf_get_option(0, "buftype") == "nofile" or buf_get_option(0, "filetype") == "netrw" then
    -- Likely a file explorer or some other special type of buffer. Set a short
    -- path statusline for these types of buffers.
    opt_local.statusline = pathshorten(fnamemodify(getcwd(), ":~:."))
    if g.lineflyWinBar then
      opt_local.winbar = nil
    end
  elseif buf_get_option(0, "buftype") == "nowrite" then
    -- Don't set a custom statusline for certain special windows.
    return
  elseif active then
    opt_local.statusline = "%{%v:lua.linefly.active_statusline()%}"
    if g.lineflyWinBar and utils.window_count() > 1 then
      opt_local.winbar = "%{%v:lua.linefly.active_winbar()%}"
    else
      opt_local.winbar = nil
    end
  else
    opt_local.statusline = "%{%v:lua.linefly.inactive_statusline()%}"
    if g.lineflyWinBar and winheight(0) > 1 then
      opt_local.winbar = "%{%v:lua.linefly.inactive_winbar()%}"
    else
      opt_local.winbar = nil
    end
  end
end

------------------------------------------------------------
-- Window bar
------------------------------------------------------------

M.active_winbar = function()
  local current_mode = mode().mode

  local winbar = modes_map[current_mode][1]
  winbar = winbar .. string.sub(modes_map[current_mode][2], 1, 2)
  winbar = winbar .. " %* %<" .. utils.filename()
  winbar = winbar .. "%{&modified ? '+ ' : '   '}"
  winbar = winbar .. "%{&readonly ? 'RO ' : ''}"
  winbar = winbar .. "%#Normal#"

  return winbar
end

M.inactive_winbar = function()
  local winbar = " %*%<" .. utils.filename()
  winbar = winbar .. "%{&modified?'+ ':'   '}"
  winbar = winbar .. "%{&readonly?'RO ':''}"
  winbar = winbar .. "%#NonText#"

  return winbar
end

------------------------------------------------------------
-- Tab line
------------------------------------------------------------

M.active_tabline = function()
  local symbol = g.lineflyAsciiShapes and "*" or "▪"
  local tabline = ""
  local counter = 0

  for _ = 1, tabpagenr("$"), 1 do
    counter = counter + 1
    tabline = tabline .. "%" .. counter .. "T"
    if tabpagenr() == counter then
      tabline = tabline .. "%#TablineSelSymbol#" .. symbol .. "%#TablineSel# Tab:"
    else
      tabline = tabline .. "%#TabLine#  Tab:"
    end
    tabline = tabline .. counter .. "%T" .. "  %#TabLineFill#"
  end

  return tabline
end

M.tabline = function()
  if g.lineflyTabLine then
    opt.tabline = "%!v:lua.linefly.active_tabline()"
  end
end

return M
