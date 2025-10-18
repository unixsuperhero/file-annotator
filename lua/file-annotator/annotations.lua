local M = {}
local state = require("file-annotator").state

-- Helper function for silent messaging
local function silent_message(msg, level)
  level = level or vim.log.levels.INFO

  -- Split multi-line messages and handle each line separately
  local lines = vim.split(msg, "\n", { plain = true })

  for _, line in ipairs(lines) do
    -- Escape single quotes by doubling them
    local escaped_line = line:gsub("'", "''")

    if level == vim.log.levels.ERROR then
      vim.cmd("silent echohl ErrorMsg")
      vim.cmd(string.format("silent echom '%s'", escaped_line))
      vim.cmd("silent echohl None")
    elseif level == vim.log.levels.WARN then
      vim.cmd("silent echohl WarningMsg")
      vim.cmd(string.format("silent echom '%s'", escaped_line))
      vim.cmd("silent echohl None")
    else
      vim.cmd(string.format("silent echom '%s'", escaped_line))
    end
  end
end

-- Label management
function M.add_label(label_name, color)
  if not label_name or label_name == "" then
    vim.notify("Label name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if state.labels[label_name] then
    vim.notify("Label '" .. label_name .. "' already exists", vim.log.levels.WARN)
    return false
  end

  local config = require("file-annotator").config
  local used_colors = {}
  for _, label in pairs(state.labels) do
    used_colors[label.color] = true
  end

  if not color then
    for _, default_color in ipairs(config.default_colors) do
      if not used_colors[default_color] then
        color = default_color
        break
      end
    end

    if not color then
      color = config.default_colors[math.random(#config.default_colors)]
    end
  end

  state.labels[label_name] = {
    color = color,
    created_at = os.time()
  }

  require("file-annotator.highlights").create_highlight_group(label_name, color)

  silent_message("Added label '" .. label_name .. "'", vim.log.levels.INFO)
  return true
end

function M.remove_label(label_name)
  if not state.labels[label_name] then
    vim.notify("Label '" .. label_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  state.labels[label_name] = nil

  if state.annotations[label_name] then
    state.annotations[label_name] = nil
  end

  require("file-annotator.highlights").refresh_buffer()

  silent_message("Removed label '" .. label_name .. "'", vim.log.levels.INFO)
  return true
end

function M.rename_label(old_name, new_name)
  if not state.labels[old_name] then
    vim.notify("Label '" .. old_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if state.labels[new_name] then
    vim.notify("Label '" .. new_name .. "' already exists", vim.log.levels.ERROR)
    return false
  end

  state.labels[new_name] = state.labels[old_name]
  state.labels[old_name] = nil

  if state.annotations[old_name] then
    state.annotations[new_name] = state.annotations[old_name]
    state.annotations[old_name] = nil
  end

  require("file-annotator.highlights").create_highlight_group(new_name, state.labels[new_name].color)
  require("file-annotator.highlights").refresh_buffer()

  silent_message("Renamed label '" .. old_name .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
  return true
end

function M.list_labels()
  local labels = {}
  for name, label in pairs(state.labels) do
    table.insert(labels, {
      name = name,
      color = label.color
    })
  end

  table.sort(labels, function(a, b) return a.name < b.name end)
  return labels
end

-- Annotation functions
function M.annotate_line(line_num, label_name, col_start, col_end)
  if not label_name or label_name == "" then
    vim.notify("Label name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  -- Auto-create label if it doesn't exist
  if not state.labels[label_name] then
    M.add_label(label_name)
    silent_message("Auto-created label: " .. label_name, vim.log.levels.INFO)
  end

  if not state.annotations[label_name] then
    state.annotations[label_name] = {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if line_num < 1 or line_num > line_count then
    vim.notify("Line number " .. line_num .. " is out of range", vim.log.levels.ERROR)
    return false
  end

  -- Validate column range if provided
  if col_start and col_end then
    local line_content = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]
    local line_length = #line_content
    if col_start < 0 or col_end > line_length or col_start >= col_end then
      vim.notify("Invalid column range", vim.log.levels.ERROR)
      return false
    end
  end

  if not state.annotations[label_name][line_num] then
    state.annotations[label_name][line_num] = {}
  end

  -- Generate unique ID for this annotation
  local annotation_id = os.time() .. "_" .. math.random(1000, 9999)

  state.annotations[label_name][line_num][annotation_id] = {
    bufnr = bufnr,
    filename = vim.api.nvim_buf_get_name(bufnr),
    timestamp = os.time(),
    col_start = col_start,
    col_end = col_end
  }

  require("file-annotator.highlights").apply_highlight(label_name, line_num)
  return true
end

function M.remove_annotation(line_num, label_name)
  if not state.annotations[label_name] or
     not state.annotations[label_name][line_num] then
    vim.notify("No annotation found at line " .. line_num, vim.log.levels.WARN)
    return false
  end

  state.annotations[label_name][line_num] = nil

  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, state.namespace, line_num - 1, line_num)

  return true
end

function M.toggle_annotation(line_num, label_name)
  if state.annotations[label_name] and
     state.annotations[label_name][line_num] then
    return M.remove_annotation(line_num, label_name)
  else
    return M.annotate_line(line_num, label_name)
  end
end

function M.clear_all_annotations(label_name)
  if label_name then
    if state.annotations[label_name] then
      state.annotations[label_name] = {}
    end
    silent_message("Cleared all annotations for label: " .. label_name, vim.log.levels.INFO)
  else
    state.annotations = {}
    silent_message("Cleared all annotations", vim.log.levels.INFO)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, state.namespace, 0, -1)

  return true
end

function M.get_line_annotations(line_num)
  local annotations = {}

  for label_name, label_annotations in pairs(state.annotations) do
    if label_annotations[line_num] then
      table.insert(annotations, {
        label = label_name,
        color = state.labels[label_name].color
      })
    end
  end

  return annotations
end

function M.get_all_annotations()
  return state.annotations
end

function M.annotate_selection(label_name)
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local start_col = vim.fn.col("'<") - 1  -- Convert to 0-based
  local end_col = vim.fn.col("'>")  -- Inclusive end
  local mode = vim.fn.visualmode()

  local success_count = 0

  -- Handle character-wise visual selection
  if mode == 'v' then
    if start_line == end_line then
      -- Single line character selection
      if M.annotate_line(start_line, label_name, start_col, end_col) then
        success_count = success_count + 1
        silent_message("Annotated character range (cols " .. start_col .. "-" .. end_col .. ") with label '" .. label_name .. "'", vim.log.levels.INFO)
      end
    else
      -- Multi-line character selection - annotate each line with appropriate column ranges
      for line_num = start_line, end_line do
        local col_s, col_e
        if line_num == start_line then
          col_s = start_col
          col_e = nil  -- To end of line
        elseif line_num == end_line then
          col_s = 0  -- From start of line
          col_e = end_col
        else
          col_s = nil  -- Whole line
          col_e = nil
        end

        if M.annotate_line(line_num, label_name, col_s, col_e) then
          success_count = success_count + 1
        end
      end
      silent_message("Annotated " .. success_count .. " lines with label '" .. label_name .. "'", vim.log.levels.INFO)
    end
  else
    -- Line-wise or block-wise visual selection - annotate whole lines
    for line_num = start_line, end_line do
      if M.annotate_line(line_num, label_name) then
        success_count = success_count + 1
      end
    end
    silent_message("Annotated " .. success_count .. " lines with label '" .. label_name .. "'", vim.log.levels.INFO)
  end

  return success_count > 0
end

function M.annotate_range(start_line, end_line, label_name)
  if not start_line or not end_line then
    vim.notify("Invalid range specified", vim.log.levels.ERROR)
    return false
  end

  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local success_count = 0
  for line_num = start_line, end_line do
    if M.annotate_line(line_num, label_name) then
      success_count = success_count + 1
    end
  end

  if success_count > 1 then
    silent_message("Annotated " .. success_count .. " lines (lines " .. start_line .. "-" .. end_line .. ") with label '" .. label_name .. "'", vim.log.levels.INFO)
  end
  return success_count > 0
end

return M
