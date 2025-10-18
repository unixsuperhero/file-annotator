local M = {}
local state = require("file-annotator").state

-- Helper function for silent messaging
local function silent_message(msg, level)
  level = level or vim.log.levels.INFO
  local lines = vim.split(msg, "\n", { plain = true })

  for _, line in ipairs(lines) do
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

local config = require("file-annotator").config

function M.export_to_html(filename, options)
  options = options or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if not filename then
    local base_name = vim.fn.fnamemodify(current_file, ":t:r")
    filename = base_name .. "_annotated_" .. os.date("%Y%m%d_%H%M%S") .. ".html"
  end

  local output_path = vim.fn.getcwd() .. "/" .. filename
  local html_content = M.generate_html(lines, current_file, options)

  local file = io.open(output_path, "w")
  if not file then
    vim.notify("Failed to create export file: " .. output_path, vim.log.levels.ERROR)
    return false
  end

  file:write(html_content)
  file:close()

  silent_message("Exported to: " .. output_path, vim.log.levels.INFO)
  return output_path
end

function M.generate_html(lines, filename, options)
  local title = options.title or ("File Annotations: " .. vim.fn.fnamemodify(filename, ":t"))

  local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. title .. [[</title>
    <style>
        body {
            font-family: 'Courier New', monospace;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 100%;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            border-bottom: 2px solid #333;
            padding-bottom: 10px;
            margin-bottom: 20px;
        }
        .filename {
            font-size: 18px;
            font-weight: bold;
            color: #333;
        }
        .metadata {
            color: #666;
            font-size: 12px;
            margin-top: 5px;
        }
        .legend {
            margin-bottom: 15px;
            padding: 10px;
            background: #f0f0f0;
            border-radius: 3px;
            font-size: 11px;
        }
        .legend-item {
            display: inline-block;
            margin-right: 12px;
            margin-bottom: 3px;
            padding: 2px 6px;
            border-radius: 2px;
            color: white;
            font-weight: bold;
        }
        .code-container {
            border: 1px solid #ddd;
            border-radius: 5px;
            overflow: auto;
            font-size: 13px;
        }
        .line {
            display: flex;
            min-height: 22px;
            line-height: 22px;
            position: relative;
        }
        .line:hover {
            background-color: rgba(0,0,0,0.02);
        }
        .line-number {
            background: #f8f8f8;
            color: #666;
            padding: 0 10px;
            text-align: right;
            min-width: 50px;
            border-right: 1px solid #ddd;
            user-select: none;
            flex-shrink: 0;
        }
        .line-content {
            padding: 0 10px;
            white-space: pre;
            flex: 1;
            overflow-x: auto;
            position: relative;
        }
        .line-skip {
            display: flex;
            min-height: 22px;
            line-height: 22px;
            background-color: #f8f8f8;
            font-style: italic;
            color: #999;
        }
        .skip-indicator {
            text-align: center !important;
        }
        .skip-text {
            color: #999;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="filename">]] .. vim.fn.fnamemodify(filename, ":t") .. [[</div>
            <div class="metadata">
                Exported on ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[<br>
                Source: ]] .. filename .. [[
            </div>
        </div>

        <div class="legend">
            <strong>Labels:</strong> ]] .. M.generate_legend() .. [[
        </div>

        <div class="code-container">
]] .. M.generate_lines(lines) .. [[
        </div>
    </div>
</body>
</html>
]]

  return html
end

function M.generate_legend()
  local legend = ""
  for label_name, label in pairs(state.labels) do
    legend = legend .. string.format([[<span class="legend-item" style="background-color: %s; color: %s;">%s</span>]],
      label.color, M.get_contrasting_color(label.color), label_name)
  end
  return legend
end

function M.generate_lines(lines)
  -- Build annotation map
  local annotation_map = {}
  for i = 1, #lines do
    local line_annotations = M.get_line_annotations(i)
    if #line_annotations > 0 then
      annotation_map[i] = line_annotations
    end
  end

  local html_lines = ""
  local current_line = 1

  while current_line <= #lines do
    local next_annotated = nil

    -- Find next annotated line
    for i = current_line, #lines do
      if annotation_map[i] then
        next_annotated = i
        break
      end
    end

    if not next_annotated then
      break
    end

    -- Add skip indicator
    if next_annotated > current_line then
      local skip_count = next_annotated - current_line
      html_lines = html_lines .. string.format([[
            <div class="line-skip">
                <div class="line-number skip-indicator">...</div>
                <div class="line-content skip-text">(%d lines)</div>
            </div>
]], skip_count)
    end

    -- Add annotated line
    local i = next_annotated
    local line = lines[i]
    local line_annotations = annotation_map[i]

    -- Create background style for multiple labels
    local bg_style = ""
    if #line_annotations == 1 then
      bg_style = string.format("background-color: %s; color: %s;",
        line_annotations[1].color, M.get_contrasting_color(line_annotations[1].color))
    elseif #line_annotations > 1 then
      local colors = {}
      for _, ann in ipairs(line_annotations) do
        table.insert(colors, ann.color .. "40")  -- Add transparency
      end
      bg_style = string.format("background: linear-gradient(90deg, %s);", table.concat(colors, ", "))
    end

    html_lines = html_lines .. string.format([[
            <div class="line">
                <div class="line-number">%d</div>
                <div class="line-content" style="%s">%s</div>
            </div>
]], i, bg_style, M.escape_html(line))

    current_line = next_annotated + 1
  end

  return html_lines
end

function M.get_line_annotations(line_num)
  local annotations = {}

  for label_name, label_annotations in pairs(state.annotations) do
    local line_data = label_annotations[line_num]
    if line_data and type(line_data) == "table" then
      -- Check if line has annotations
      local has_annotations = false
      for k, v in pairs(line_data) do
        if type(v) == "table" and v.bufnr then
          has_annotations = true
          break
        end
      end

      if has_annotations and state.labels[label_name] then
        table.insert(annotations, {
          label = label_name,
          color = state.labels[label_name].color
        })
      end
    end
  end

  return annotations
end

function M.escape_html(text)
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&#39;")
end

function M.get_contrasting_color(hex_color)
  local r, g, b = hex_color:match("#(%x%x)(%x%x)(%x%x)")
  if not r then return "#000000" end

  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

  return luminance > 0.5 and "#000000" or "#FFFFFF"
end

-- JSON export/import
function M.export_annotations_to_json(filename)
  local data = {
    version = "2.0",
    export_timestamp = os.time(),
    export_date = os.date("%Y-%m-%d %H:%M:%S"),
    labels = state.labels,
    annotations = state.annotations
  }

  if not filename then
    filename = "annotations_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
  end

  local output_path = vim.fn.getcwd() .. "/" .. filename
  local json_data = vim.fn.json_encode(data)

  local file = io.open(output_path, "w")
  if not file then
    vim.notify("Failed to create annotation export file: " .. output_path, vim.log.levels.ERROR)
    return false
  end

  file:write(json_data)
  file:close()

  silent_message("Annotations exported to: " .. output_path, vim.log.levels.INFO)
  return output_path
end

function M.import_annotations_from_json(filename)
  local file = io.open(filename, "r")
  if not file then
    vim.notify("Annotation file not found: " .. filename, vim.log.levels.ERROR)
    return false
  end

  local content = file:read("*a")
  file:close()

  local success, data = pcall(vim.fn.json_decode, content)
  if not success then
    vim.notify("Failed to parse annotation file: " .. filename, vim.log.levels.ERROR)
    return false
  end

  if not data.labels or not data.annotations then
    vim.notify("Invalid annotation file format: " .. filename, vim.log.levels.ERROR)
    return false
  end

  -- Show import preview
  local stats = M.get_import_stats(data)
  local confirmation = vim.fn.confirm(
    string.format("Import %d labels with %d total annotations?\n\nThis will replace current annotations.",
                  stats.label_count, stats.annotation_count),
    "&Yes\n&No\n&Merge",
    2
  )

  if confirmation == 2 then
    silent_message("Import cancelled", vim.log.levels.INFO)
    return false
  elseif confirmation == 3 then
    return M.merge_annotations(data)
  else
    return M.replace_annotations(data)
  end
end

function M.get_import_stats(data)
  local label_count = vim.tbl_count(data.labels or {})
  local annotation_count = 0

  for _, label_annotations in pairs(data.annotations or {}) do
    for _, line_data in pairs(label_annotations) do
      if type(line_data) == "table" then
        annotation_count = annotation_count + vim.tbl_count(line_data)
      end
    end
  end

  return {
    label_count = label_count,
    annotation_count = annotation_count,
    export_date = data.export_date or "Unknown"
  }
end

function M.replace_annotations(data)
  vim.api.nvim_buf_clear_namespace(0, state.namespace, 0, -1)

  state.labels = data.labels or {}
  state.annotations = data.annotations or {}

  -- Recreate highlight groups
  for label_name, label in pairs(state.labels) do
    require("file-annotator.highlights").create_highlight_group(label_name, label.color)
  end

  require("file-annotator.highlights").refresh_buffer()

  local stats = M.get_import_stats(data)
  silent_message(string.format("Successfully imported %d labels with %d annotations (exported: %s)",
                           stats.label_count, stats.annotation_count, stats.export_date),
             vim.log.levels.INFO)
  return true
end

function M.merge_annotations(data)
  local conflicts = 0
  local imported = 0

  -- Merge labels
  for label_name, label_data in pairs(data.labels or {}) do
    if not state.labels[label_name] then
      state.labels[label_name] = label_data
      require("file-annotator.highlights").create_highlight_group(label_name, label_data.color)
    end
  end

  -- Merge annotations
  for label_name, label_annotations in pairs(data.annotations or {}) do
    if not state.annotations[label_name] then
      state.annotations[label_name] = label_annotations
      for line_num, line_data in pairs(label_annotations) do
        if type(line_data) == "table" then
          imported = imported + vim.tbl_count(line_data)
        end
      end
    else
      for line_num, line_data in pairs(label_annotations) do
        if not state.annotations[label_name][line_num] then
          state.annotations[label_name][line_num] = line_data
          if type(line_data) == "table" then
            imported = imported + vim.tbl_count(line_data)
          end
        else
          if type(line_data) == "table" then
            conflicts = conflicts + vim.tbl_count(line_data)
          end
        end
      end
    end
  end

  require("file-annotator.highlights").refresh_buffer()

  local message = string.format("Merge completed: %d annotations imported", imported)
  if conflicts > 0 then
    message = message .. string.format(", %d conflicts skipped", conflicts)
  end
  silent_message(message, vim.log.levels.INFO)
  return true
end

function M.export_label_stats()
  local stats = {
    labels = {},
    total_annotations = 0,
    label_count = 0,
    export_time = os.time()
  }

  for label_name, label_annotations in pairs(state.annotations) do
    local label_count = 0
    for line_num, line_data in pairs(label_annotations) do
      if type(line_data) == "table" then
        for annotation_id, annotation in pairs(line_data) do
          if type(annotation) == "table" and annotation.bufnr then
            label_count = label_count + 1
          end
        end
      end
    end

    stats.labels[label_name] = label_count
    stats.total_annotations = stats.total_annotations + label_count
  end

  stats.label_count = vim.tbl_count(state.labels)
  return stats
end

return M
