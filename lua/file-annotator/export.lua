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

  -- Export to current working directory instead of plugin data directory
  local output_path = vim.fn.getcwd() .. "/" .. filename

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

  -- Get all layers and their colors
  local layer_info = M.get_layer_info()

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
        .layer-controls {
            margin-bottom: 20px;
            padding: 15px;
            background: #f9f9f9;
            border-radius: 5px;
            border: 1px solid #ddd;
        }
        .layer-controls h3 {
            margin-top: 0;
            margin-bottom: 10px;
            color: #333;
        }
        .layer-toggle {
            display: inline-block;
            margin-right: 10px;
            margin-bottom: 5px;
            padding: 8px 12px;
            border: 2px solid;
            border-radius: 5px;
            cursor: pointer;
            user-select: none;
            font-size: 12px;
            font-weight: bold;
            transition: all 0.2s ease;
        }
        .layer-toggle.active {
            transform: scale(0.95);
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.2);
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
        .line-indicators {
            width: 30px;
            background: #f8f8f8;
            border-right: 1px solid #ddd;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            flex-shrink: 0;
            padding: 1px;
        }
        .layer-indicator {
            width: 6px;
            height: 6px;
            border-radius: 50%;
            margin: 1px;
            display: none;
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
]] .. M.generate_layer_styles(layer_info) .. [[
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

        <div class="layer-controls">
            <h3>Layer Controls</h3>
            <div style="font-size: 11px; color: #666; margin-bottom: 8px;">
                Click to toggle layers • Shift+click to show only that layer
            </div>
            <div class="controls">
]] .. M.generate_interactive_layer_controls(layer_info) .. [[
            </div>
            <div class="legend">
]] .. M.generate_interactive_legend(layer_info) .. [[
            </div>
        </div>

        <div class="code-container">
]] .. M.generate_interactive_lines(lines, layer_info) .. [[
        </div>
    </div>

    <script>
]] .. M.generate_javascript(layer_info) .. [[
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

function M.get_layer_info()
  local layer_info = {}
  local distinct_colors = {
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
    "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
    "#FF8C94", "#A8E6CF", "#B4E5F1", "#C7CEEA", "#FFD93D"
  }

  local color_index = 1
  for layer_name, layer in pairs(state.layers) do
    layer_info[layer_name] = {
      name = layer_name,
      color = distinct_colors[color_index] or distinct_colors[1],
      labels = {}
    }

    for label_name, label in pairs(layer.labels) do
      layer_info[layer_name].labels[label_name] = {
        name = label_name,
        color = label.color
      }
    end

    color_index = color_index + 1
    if color_index > #distinct_colors then
      color_index = 1
    end
  end

  return layer_info
end

function M.generate_layer_styles(layer_info)
  local styles = ""

  for layer_name, layer in pairs(layer_info) do
    -- Layer-specific background styles
    styles = styles .. string.format([[
        .line.layer-%s-active .line-content {
            background-color: %s !important;
            color: %s !important;
        }
        .layer-indicator.%s {
            background-color: %s;
        }
        .layer-toggle[data-layer="%s"] {
            background-color: %s;
            border-color: %s;
            color: %s;
        }
]],
      layer_name,
      layer.color .. "40", -- Add transparency
      M.get_contrasting_color(layer.color),
      layer_name,
      layer.color,
      layer_name,
      layer.color .. "20", -- Light background
      layer.color,
      M.get_contrasting_color(layer.color)
    )
  end

  return styles
end

function M.generate_interactive_layer_controls(layer_info)
  local controls = ""

  for layer_name, layer in pairs(layer_info) do
    controls = controls .. string.format([[
                <span class="layer-toggle" data-layer="%s">%s</span>
]], layer_name, layer_name)
  end

  return controls
end

function M.generate_interactive_legend(layer_info)
  local legend = ""

  for layer_name, layer in pairs(layer_info) do
    legend = legend .. string.format([[<strong>%s:</strong> ]], layer_name)

    for label_name, label in pairs(layer.labels) do
      legend = legend .. string.format([[<span class="legend-item" style="background-color: %s; color: %s;">%s</span>]],
        label.color, M.get_contrasting_color(label.color), label_name)
    end

    legend = legend .. "<br>"
  end

  return legend
end

function M.generate_interactive_lines(lines, layer_info)
  local html_lines = ""

  for i, line in ipairs(lines) do
    local line_annotations = M.get_all_line_annotations(i)

    -- Generate layer indicators
    local indicators = ""
    for layer_name, _ in pairs(layer_info) do
      indicators = indicators .. string.format([[<div class="layer-indicator %s" data-layer="%s"></div>]],
        layer_name, layer_name)
    end

    -- Generate data attributes for each layer
    local data_attrs = ""
    local layer_classes = ""
    for layer_name, annotations in pairs(line_annotations) do
      if #annotations > 0 then
        data_attrs = data_attrs .. string.format([[ data-%s-labels="%s"]],
          layer_name, table.concat(vim.tbl_map(function(a) return a.label end, annotations), ","))
        layer_classes = layer_classes .. " has-" .. layer_name
      end
    end

    html_lines = html_lines .. string.format([[
            <div class="line%s" data-line="%d"%s>
                <div class="line-indicators">%s</div>
                <div class="line-number">%d</div>
                <div class="line-content">%s</div>
            </div>
]], layer_classes, i, data_attrs, indicators, i, M.escape_html(line))
  end

  return html_lines
end

function M.get_all_line_annotations(line_num)
  local annotations_by_layer = {}

  for layer_name, layer_annotations in pairs(state.annotations) do
    annotations_by_layer[layer_name] = {}

    for label_name, label_annotations in pairs(layer_annotations) do
      if label_annotations[line_num] then
        table.insert(annotations_by_layer[layer_name], {
          layer = layer_name,
          label = label_name,
          color = state.layers[layer_name].labels[label_name].color
        })
      end
    end
  end

  return annotations_by_layer
end

function M.generate_javascript(layer_info)
  local layer_names = {}
  for layer_name, _ in pairs(layer_info) do
    table.insert(layer_names, '"' .. layer_name .. '"')
  end

  return string.format([[
        const layers = [%s];
        const activeLayers = new Set();

        document.addEventListener('DOMContentLoaded', function() {
            const toggles = document.querySelectorAll('.layer-toggle');

            toggles.forEach(toggle => {
                toggle.addEventListener('click', function(event) {
                    const layer = this.dataset.layer;

                    if (event.shiftKey) {
                        // Shift+click: Turn on this layer and turn off all others
                        activeLayers.clear();
                        activeLayers.add(layer);

                        // Update all toggle buttons
                        toggles.forEach(t => {
                            if (t.dataset.layer === layer) {
                                t.classList.add('active');
                            } else {
                                t.classList.remove('active');
                            }
                        });
                    } else {
                        // Normal click: Toggle this layer
                        if (activeLayers.has(layer)) {
                            activeLayers.delete(layer);
                            this.classList.remove('active');
                        } else {
                            activeLayers.add(layer);
                            this.classList.add('active');
                        }
                    }

                    updateDisplay();
                });
            });

            // Add "All" and "None" buttons
            const controlsDiv = document.querySelector('.controls');
            const allBtn = document.createElement('span');
            allBtn.textContent = 'All';
            allBtn.className = 'layer-toggle';
            allBtn.style.backgroundColor = '#28a745';
            allBtn.style.borderColor = '#28a745';
            allBtn.style.color = 'white';
            allBtn.addEventListener('click', function() {
                activeLayers.clear();
                layers.forEach(layer => activeLayers.add(layer));
                toggles.forEach(t => t.classList.add('active'));
                updateDisplay();
            });

            const noneBtn = document.createElement('span');
            noneBtn.textContent = 'None';
            noneBtn.className = 'layer-toggle';
            noneBtn.style.backgroundColor = '#dc3545';
            noneBtn.style.borderColor = '#dc3545';
            noneBtn.style.color = 'white';
            noneBtn.addEventListener('click', function() {
                activeLayers.clear();
                toggles.forEach(t => t.classList.remove('active'));
                updateDisplay();
            });

            controlsDiv.appendChild(allBtn);
            controlsDiv.appendChild(noneBtn);
        });

        function updateDisplay() {
            const lines = document.querySelectorAll('.line');

            lines.forEach(line => {
                // Clear all layer-specific classes
                layers.forEach(layer => {
                    line.classList.remove('layer-' + layer + '-active');
                });

                // Hide all indicators
                const indicators = line.querySelectorAll('.layer-indicator');
                indicators.forEach(indicator => {
                    indicator.style.display = 'none';
                });

                // Show indicators and apply styles for active layers
                let hasActiveAnnotations = false;
                activeLayers.forEach(layer => {
                    const labels = line.getAttribute('data-' + layer + '-labels');
                    if (labels && labels.length > 0) {
                        hasActiveAnnotations = true;

                        // Show indicator for this layer
                        const indicator = line.querySelector('.layer-indicator.' + layer);
                        if (indicator) {
                            indicator.style.display = 'block';
                        }

                        // Apply layer styling
                        line.classList.add('layer-' + layer + '-active');
                    }
                });

                // Apply combined styling for multiple active layers
                if (activeLayers.size > 1) {
                    const activeLayersOnLine = [];
                    activeLayers.forEach(layer => {
                        const labels = line.getAttribute('data-' + layer + '-labels');
                        if (labels && labels.length > 0) {
                            activeLayersOnLine.push(layer);
                        }
                    });

                    if (activeLayersOnLine.length > 1) {
                        // Create gradient for multiple layers
                        line.classList.remove(...activeLayersOnLine.map(l => 'layer-' + l + '-active'));
                        // Add your gradient logic here if needed
                    }
                }
            });
        }
]], table.concat(layer_names, ", "))
end

return M