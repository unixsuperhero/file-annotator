local M = {}
local state = require("file-annotator").state
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

  local output_path = config.export_dir .. "/" .. filename

  local html_content = M.generate_html(lines, current_file, options)

  local file = io.open(output_path, "w")
  if not file then
    vim.notify("Failed to create export file: " .. output_path, vim.log.levels.ERROR)
    return false
  end

  file:write(html_content)
  file:close()

  vim.notify("Exported to: " .. output_path, vim.log.levels.INFO)
  return output_path
end

function M.generate_html(lines, filename, options)
  local title = options.title or ("File Annotations: " .. vim.fn.fnamemodify(filename, ":t"))
  local include_layers = options.layers or {}
  local show_legend = options.show_legend ~= false

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
            margin-bottom: 20px;
            padding: 15px;
            background: #f9f9f9;
            border-radius: 5px;
            border: 1px solid #ddd;
        }
        .legend h3 {
            margin-top: 0;
            color: #333;
        }
        .legend-layer {
            margin-bottom: 10px;
        }
        .legend-layer-name {
            font-weight: bold;
            margin-bottom: 5px;
        }
        .legend-item {
            display: inline-block;
            margin-right: 15px;
            margin-bottom: 5px;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 11px;
            color: white;
        }
        .code-container {
            border: 1px solid #ddd;
            border-radius: 5px;
            overflow: auto;
        }
        .line {
            display: flex;
            min-height: 20px;
            line-height: 20px;
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
        }
        .layer-controls {
            margin-bottom: 15px;
        }
        .layer-toggle {
            display: inline-block;
            margin-right: 10px;
            padding: 5px 10px;
            background: #e9ecef;
            border: 1px solid #adb5bd;
            border-radius: 3px;
            cursor: pointer;
            user-select: none;
            font-size: 12px;
        }
        .layer-toggle.active {
            background: #007bff;
            color: white;
            border-color: #007bff;
        }
        .multiple-annotations {
            background: linear-gradient(to right, ]] .. M.get_gradient_colors() .. [[);
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
]]

  if show_legend then
    html = html .. M.generate_legend(include_layers)
  end

  html = html .. M.generate_layer_controls() .. [[
        <div class="code-container">
]]

  for i, line in ipairs(lines) do
    local line_annotations = M.get_line_annotations_for_export(i, include_layers)
    local line_class = ""
    local inline_style = ""

    if #line_annotations > 0 then
      if #line_annotations == 1 then
        inline_style = string.format(' style="background-color: %s; color: %s;"',
          line_annotations[1].color,
          M.get_contrasting_color(line_annotations[1].color))
      else
        line_class = " multiple-annotations"
        inline_style = string.format(' style="background: %s;"', M.create_gradient(line_annotations))
      end
    end

    html = html .. string.format([[
            <div class="line%s"%s data-line="%d">
                <div class="line-number">%d</div>
                <div class="line-content">%s</div>
            </div>
]], line_class, inline_style, i, i, M.escape_html(line))
  end

  html = html .. [[
        </div>
    </div>
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const toggles = document.querySelectorAll('.layer-toggle');
            toggles.forEach(toggle => {
                toggle.addEventListener('click', function() {
                    this.classList.toggle('active');
                    const layer = this.dataset.layer;
                    // Toggle layer visibility logic would go here
                    // For now, this is just visual feedback
                });
            });
        });
    </script>
</body>
</html>
]]

  return html
end

function M.get_line_annotations_for_export(line_num, include_layers)
  local annotations = {}

  for layer_name, layer_annotations in pairs(state.annotations) do
    if state.layers[layer_name] and state.layers[layer_name].visible then
      if #include_layers == 0 or vim.tbl_contains(include_layers, layer_name) then
        for label_name, label_annotations in pairs(layer_annotations) do
          if label_annotations[line_num] then
            table.insert(annotations, {
              layer = layer_name,
              label = label_name,
              color = state.layers[layer_name].labels[label_name].color
            })
          end
        end
      end
    end
  end

  return annotations
end

function M.generate_legend(include_layers)
  local legend_html = [[
        <div class="legend">
            <h3>Annotation Legend</h3>
]]

  for layer_name, layer in pairs(state.layers) do
    if #include_layers == 0 or vim.tbl_contains(include_layers, layer_name) then
      legend_html = legend_html .. string.format([[
            <div class="legend-layer">
                <div class="legend-layer-name">%s</div>
]], layer_name)

      for label_name, label in pairs(layer.labels) do
        legend_html = legend_html .. string.format([[
                <span class="legend-item" style="background-color: %s; color: %s;">%s</span>
]], label.color, M.get_contrasting_color(label.color), label_name)
      end

      legend_html = legend_html .. [[
            </div>
]]
    end
  end

  legend_html = legend_html .. [[
        </div>
]]

  return legend_html
end

function M.generate_layer_controls()
  local controls_html = [[
        <div class="layer-controls">
            <strong>Layers:</strong>
]]

  for layer_name, layer in pairs(state.layers) do
    local active_class = layer.visible and " active" or ""
    controls_html = controls_html .. string.format([[
            <span class="layer-toggle%s" data-layer="%s">%s</span>
]], active_class, layer_name, layer_name)
  end

  controls_html = controls_html .. [[
        </div>
]]

  return controls_html
end

function M.create_gradient(annotations)
  if #annotations <= 1 then
    return annotations[1] and annotations[1].color or "#ffffff"
  end

  local colors = {}
  for _, annotation in ipairs(annotations) do
    table.insert(colors, annotation.color)
  end

  local step = 100 / #colors
  local gradient_stops = {}

  for i, color in ipairs(colors) do
    local start_pos = (i - 1) * step
    local end_pos = i * step
    table.insert(gradient_stops, string.format("%s %d%%, %s %d%%", color, start_pos, color, end_pos))
  end

  return "linear-gradient(to right, " .. table.concat(gradient_stops, ", ") .. ")"
end

function M.get_gradient_colors()
  -- Fallback gradient for CSS
  return "#ff6b6b 0%, #4ecdc4 25%, #45b7d1 50%, #96ceb4 75%, #ffeaa7 100%"
end

function M.get_contrasting_color(hex_color)
  local r, g, b = hex_color:match("#(%x%x)(%x%x)(%x%x)")
  if not r then return "#000000" end

  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255

  return luminance > 0.5 and "#000000" or "#FFFFFF"
end

function M.escape_html(text)
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&#39;")
end

function M.export_layer_stats()
  local stats = {
    layers = {},
    total_annotations = 0,
    export_time = os.time()
  }

  for layer_name, layer_annotations in pairs(state.annotations) do
    local layer_stats = {
      name = layer_name,
      labels = {},
      total_lines = 0
    }

    for label_name, label_annotations in pairs(layer_annotations) do
      local label_count = vim.tbl_count(label_annotations)
      layer_stats.labels[label_name] = label_count
      layer_stats.total_lines = layer_stats.total_lines + label_count
    end

    stats.layers[layer_name] = layer_stats
    stats.total_annotations = stats.total_annotations + layer_stats.total_lines
  end

  return stats
end

return M