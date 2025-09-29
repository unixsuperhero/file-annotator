local M = {}
local state = require("file-annotator").state
local config = require("file-annotator").config

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

function M.create_layer(name)
  if not name or name == "" then
    vim.notify("Layer name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if state.layers[name] then
    vim.notify("Layer '" .. name .. "' already exists", vim.log.levels.WARN)
    return false
  end

  state.layers[name] = {
    labels = {},
    visible = true,
    created_at = os.time()
  }

  state.namespaces[name] = vim.api.nvim_create_namespace("file_annotator_" .. name)

  if not state.current_layer then
    state.current_layer = name
  end

  silent_message("Created layer: " .. name, vim.log.levels.INFO)
  return true
end

function M.delete_layer(name)
  if not state.layers[name] then
    vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if name == state.current_layer then
    local remaining_layers = {}
    for layer_name, _ in pairs(state.layers) do
      if layer_name ~= name then
        table.insert(remaining_layers, layer_name)
      end
    end
    state.current_layer = remaining_layers[1]
  end

  vim.api.nvim_buf_clear_namespace(0, state.namespaces[name], 0, -1)
  state.layers[name] = nil
  state.namespaces[name] = nil

  if state.annotations[name] then
    state.annotations[name] = nil
  end

  silent_message("Deleted layer: " .. name, vim.log.levels.INFO)
  return true
end

function M.rename_layer(old_name, new_name)
  if not state.layers[old_name] then
    vim.notify("Layer '" .. old_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if state.layers[new_name] then
    vim.notify("Layer '" .. new_name .. "' already exists", vim.log.levels.ERROR)
    return false
  end

  state.layers[new_name] = state.layers[old_name]
  state.layers[old_name] = nil

  local old_ns = state.namespaces[old_name]
  state.namespaces[new_name] = vim.api.nvim_create_namespace("file_annotator_" .. new_name)
  state.namespaces[old_name] = nil

  if state.annotations[old_name] then
    state.annotations[new_name] = state.annotations[old_name]
    state.annotations[old_name] = nil
  end

  if state.current_layer == old_name then
    state.current_layer = new_name
  end

  vim.api.nvim_buf_clear_namespace(0, old_ns, 0, -1)
  require("file-annotator.highlights").refresh_buffer()

  silent_message("Renamed layer '" .. old_name .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
  return true
end

function M.duplicate_layer(source_name, new_name)
  if not state.layers[source_name] then
    vim.notify("Layer '" .. source_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  -- Auto-generate name if not provided
  if not new_name or new_name == "" then
    local layer_count = vim.tbl_count(state.layers)
    local base_name = "layer"
    local index = layer_count + 1

    -- Find next available layerN name
    repeat
      new_name = base_name .. index
      index = index + 1
    until not state.layers[new_name]

    silent_message("Auto-generated name: " .. new_name, vim.log.levels.INFO)
  end

  if state.layers[new_name] then
    vim.notify("Layer '" .. new_name .. "' already exists", vim.log.levels.ERROR)
    return false
  end

  -- Create new layer
  state.layers[new_name] = {
    labels = {},
    visible = true,
    created_at = os.time()
  }

  -- Create namespace for new layer
  state.namespaces[new_name] = vim.api.nvim_create_namespace("file_annotator_" .. new_name)

  -- Copy all labels from source layer
  for label_name, label_data in pairs(state.layers[source_name].labels) do
    state.layers[new_name].labels[label_name] = {
      color = label_data.color,
      created_at = os.time()
    }

    -- Create highlight group for the new layer's label
    require("file-annotator.highlights").create_highlight_group(new_name, label_name, label_data.color)
  end

  -- Note: We don't copy annotations, only the layer structure and labels
  silent_message("Duplicated layer '" .. source_name .. "' to '" .. new_name .. "' with " ..
             vim.tbl_count(state.layers[new_name].labels) .. " labels", vim.log.levels.INFO)
  return true
end

function M.set_current_layer(name)
  if not state.layers[name] then
    vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  state.current_layer = name
  require("file-annotator.highlights").refresh_buffer()
  silent_message("Switched to layer: " .. name, vim.log.levels.INFO)
  return true
end

function M.toggle_layer_visibility(name)
  if not state.layers[name] then
    vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  state.layers[name].visible = not state.layers[name].visible
  require("file-annotator.highlights").refresh_buffer()

  local status = state.layers[name].visible and "visible" or "hidden"
  silent_message("Layer '" .. name .. "' is now " .. status, vim.log.levels.INFO)
  return true
end

function M.list_layers()
  local layers = {}
  for name, layer in pairs(state.layers) do
    table.insert(layers, {
      name = name,
      current = name == state.current_layer,
      visible = layer.visible,
      label_count = vim.tbl_count(layer.labels)
    })
  end

  table.sort(layers, function(a, b) return a.name < b.name end)
  return layers
end

function M.add_label(layer_name, label_name, color)
  layer_name = layer_name or state.current_layer

  if not state.layers[layer_name] then
    vim.notify("Layer '" .. layer_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if not label_name or label_name == "" then
    vim.notify("Label name cannot be empty", vim.log.levels.ERROR)
    return false
  end

  if state.layers[layer_name].labels[label_name] then
    vim.notify("Label '" .. label_name .. "' already exists in layer '" .. layer_name .. "'", vim.log.levels.WARN)
    return false
  end

  local used_colors = {}
  for _, label in pairs(state.layers[layer_name].labels) do
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

  state.layers[layer_name].labels[label_name] = {
    color = color,
    created_at = os.time()
  }

  require("file-annotator.highlights").create_highlight_group(layer_name, label_name, color)

  silent_message("Added label '" .. label_name .. "' to layer '" .. layer_name .. "'", vim.log.levels.INFO)
  return true
end

function M.remove_label(layer_name, label_name)
  layer_name = layer_name or state.current_layer

  if not state.layers[layer_name] then
    vim.notify("Layer '" .. layer_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if not state.layers[layer_name].labels[label_name] then
    vim.notify("Label '" .. label_name .. "' does not exist in layer '" .. layer_name .. "'", vim.log.levels.ERROR)
    return false
  end

  state.layers[layer_name].labels[label_name] = nil

  if state.annotations[layer_name] and state.annotations[layer_name][label_name] then
    state.annotations[layer_name][label_name] = nil
  end

  require("file-annotator.highlights").refresh_buffer()

  silent_message("Removed label '" .. label_name .. "' from layer '" .. layer_name .. "'", vim.log.levels.INFO)
  return true
end

function M.rename_label(layer_name, old_name, new_name)
  layer_name = layer_name or state.current_layer

  if not state.layers[layer_name] then
    vim.notify("Layer '" .. layer_name .. "' does not exist", vim.log.levels.ERROR)
    return false
  end

  if not state.layers[layer_name].labels[old_name] then
    vim.notify("Label '" .. old_name .. "' does not exist in layer '" .. layer_name .. "'", vim.log.levels.ERROR)
    return false
  end

  if state.layers[layer_name].labels[new_name] then
    vim.notify("Label '" .. new_name .. "' already exists in layer '" .. layer_name .. "'", vim.log.levels.ERROR)
    return false
  end

  state.layers[layer_name].labels[new_name] = state.layers[layer_name].labels[old_name]
  state.layers[layer_name].labels[old_name] = nil

  if state.annotations[layer_name] and state.annotations[layer_name][old_name] then
    state.annotations[layer_name][new_name] = state.annotations[layer_name][old_name]
    state.annotations[layer_name][old_name] = nil
  end

  require("file-annotator.highlights").create_highlight_group(layer_name, new_name, state.layers[layer_name].labels[new_name].color)
  require("file-annotator.highlights").refresh_buffer()

  silent_message("Renamed label '" .. old_name .. "' to '" .. new_name .. "' in layer '" .. layer_name .. "'", vim.log.levels.INFO)
  return true
end

function M.get_ordered_layer_names()
  -- Get layer names in a consistent order
  if not state.layer_order then
    -- Initialize layer order with current layers
    state.layer_order = {}
    for name, _ in pairs(state.layers) do
      table.insert(state.layer_order, name)
    end
    table.sort(state.layer_order)
  end

  -- Remove non-existent layers from order
  local valid_order = {}
  for _, name in ipairs(state.layer_order) do
    if state.layers[name] then
      table.insert(valid_order, name)
    end
  end

  -- Add any new layers not in the order
  for name, _ in pairs(state.layers) do
    if not vim.tbl_contains(valid_order, name) then
      table.insert(valid_order, name)
    end
  end

  state.layer_order = valid_order
  return valid_order
end

function M.get_current_layer_index()
  if not state.current_layer then
    return nil
  end

  local ordered_layers = M.get_ordered_layer_names()
  for i, name in ipairs(ordered_layers) do
    if name == state.current_layer then
      return i
    end
  end
  return nil
end

function M.switch_to_previous_layer()
  local ordered_layers = M.get_ordered_layer_names()
  if #ordered_layers <= 1 then
    vim.notify("No other layers to switch to", vim.log.levels.WARN)
    return false
  end

  local current_index = M.get_current_layer_index()
  if not current_index then
    -- No current layer, switch to first
    return M.set_current_layer(ordered_layers[1])
  end

  local prev_index = current_index - 1
  if prev_index < 1 then
    prev_index = #ordered_layers -- Wrap to last layer
  end

  return M.set_current_layer(ordered_layers[prev_index])
end

function M.switch_to_next_layer()
  local ordered_layers = M.get_ordered_layer_names()
  if #ordered_layers <= 1 then
    vim.notify("No other layers to switch to", vim.log.levels.WARN)
    return false
  end

  local current_index = M.get_current_layer_index()
  if not current_index then
    -- No current layer, switch to first
    return M.set_current_layer(ordered_layers[1])
  end

  local next_index = current_index + 1
  if next_index > #ordered_layers then
    next_index = 1 -- Wrap to first layer
  end

  return M.set_current_layer(ordered_layers[next_index])
end

function M.reorder_layers(new_order)
  -- Validate that all layers in new_order exist
  for _, name in ipairs(new_order) do
    if not state.layers[name] then
      vim.notify("Layer '" .. name .. "' does not exist", vim.log.levels.ERROR)
      return false
    end
  end

  -- Ensure all existing layers are included
  local existing_layers = {}
  for name, _ in pairs(state.layers) do
    existing_layers[name] = true
  end

  for _, name in ipairs(new_order) do
    existing_layers[name] = nil
  end

  -- Add any missing layers to the end
  for name, _ in pairs(existing_layers) do
    table.insert(new_order, name)
  end

  state.layer_order = new_order
  silent_message("Layer order updated", vim.log.levels.INFO)
  return true
end

function M.open_layer_reorder_buffer()
  local ordered_layers = M.get_ordered_layer_names()

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer content with instructions and layer list
  local content = {
    "# File Annotator - Layer Reordering",
    "# ",
    "# Instructions:",
    "# - Reorder the layers below by moving the lines",
    "# - Save and close this buffer to apply the new order",
    "# - Each line should contain exactly one layer name",
    "# ",
    "# Current layer order:",
    ""
  }

  for i, name in ipairs(ordered_layers) do
    local marker = (name == state.current_layer) and " (current)" or ""
    table.insert(content, name .. marker)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Open buffer in a new window
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "filetype", "conf")
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_name(buf, "Layer Order")

  -- Set up autocommand to handle saving
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.process_layer_reorder_buffer(buf)
    end,
    desc = "Process layer reorder buffer"
  })

  silent_message("Edit layer order and save to apply changes", vim.log.levels.INFO)
end

function M.process_layer_reorder_buffer(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local new_order = {}

  -- Extract layer names from lines (skip comments and empty lines)
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line ~= "" and not vim.startswith(line, "#") then
      -- Remove any annotations like " (current)"
      local layer_name = line:match("^([^%s%(]+)")
      if layer_name and state.layers[layer_name] then
        table.insert(new_order, layer_name)
      end
    end
  end

  if #new_order == 0 then
    vim.notify("No valid layer names found in buffer", vim.log.levels.ERROR)
    return
  end

  -- Apply the new order
  if M.reorder_layers(new_order) then
    vim.api.nvim_buf_set_option(buf, "modified", false)
    vim.cmd("bdelete")
    silent_message("Layer order applied successfully", vim.log.levels.INFO)
  end
end

return M
