local M = {}
local layers = require("file-annotator.layers")
local annotations = require("file-annotator.annotations")
local export = require("file-annotator.export")

function M.setup()
  -- Layer management commands
  vim.api.nvim_create_user_command("FACreateLayer", function(opts)
    layers.create_layer(opts.args)
  end, {
    nargs = 1,
    desc = "Create a new annotation layer"
  })

  vim.api.nvim_create_user_command("FADeleteLayer", function(opts)
    layers.delete_layer(opts.args)
  end, {
    nargs = 1,
    complete = M.complete_layers,
    desc = "Delete an annotation layer"
  })

  vim.api.nvim_create_user_command("FARenameLayer", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })
    if #args ~= 2 then
      vim.notify("Usage: FARenameLayer <old_name> <new_name>", vim.log.levels.ERROR)
      return
    end
    layers.rename_layer(args[1], args[2])
  end, {
    nargs = "+",
    complete = M.complete_layers,
    desc = "Rename an annotation layer"
  })

  vim.api.nvim_create_user_command("FADuplicateLayer", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })
    if #args < 1 or #args > 2 then
      vim.notify("Usage: FADuplicateLayer <source_layer> [new_layer]", vim.log.levels.ERROR)
      return
    end
    layers.duplicate_layer(args[1], args[2])
  end, {
    nargs = "+",
    complete = M.complete_layers,
    desc = "Duplicate an annotation layer with all its labels (auto-names if no name given)"
  })

  vim.api.nvim_create_user_command("FASetLayer", function(opts)
    layers.set_current_layer(opts.args)
  end, {
    nargs = 1,
    complete = M.complete_layers,
    desc = "Set current annotation layer"
  })

  vim.api.nvim_create_user_command("FAToggleLayer", function(opts)
    layers.toggle_layer_visibility(opts.args)
  end, {
    nargs = 1,
    complete = M.complete_layers,
    desc = "Toggle layer visibility"
  })

  vim.api.nvim_create_user_command("FAListLayers", function()
    M.show_layers_info()
  end, {
    desc = "List all annotation layers"
  })

  vim.api.nvim_create_user_command("FAPreviousLayer", function()
    layers.switch_to_previous_layer()
  end, {
    desc = "Switch to previous layer"
  })

  vim.api.nvim_create_user_command("FANextLayer", function()
    layers.switch_to_next_layer()
  end, {
    desc = "Switch to next layer"
  })

  vim.api.nvim_create_user_command("FAReorderLayers", function()
    layers.open_layer_reorder_buffer()
  end, {
    desc = "Open buffer to reorder layers"
  })

  -- Label management commands
  vim.api.nvim_create_user_command("FAAddLabel", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })
    if #args < 1 then
      vim.notify("Usage: FAAddLabel <label_name> [color]", vim.log.levels.ERROR)
      return
    end
    local label_name = args[1]
    local color = args[2]
    layers.add_label(nil, label_name, color)
  end, {
    nargs = "+",
    desc = "Add a label to the current layer"
  })

  vim.api.nvim_create_user_command("FARemoveLabel", function(opts)
    layers.remove_label(nil, opts.args)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    desc = "Remove a label from the current layer"
  })

  vim.api.nvim_create_user_command("FARenameLabel", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })
    if #args ~= 2 then
      vim.notify("Usage: FARenameLabel <old_name> <new_name>", vim.log.levels.ERROR)
      return
    end
    layers.rename_label(nil, args[1], args[2])
  end, {
    nargs = "+",
    complete = M.complete_labels,
    desc = "Rename a label in the current layer"
  })

  -- Annotation commands
  vim.api.nvim_create_user_command("FAAnnotate", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })

    if #args < 1 or #args > 2 then
      vim.notify("Usage: FAAnnotate <label_name> [layer_name]", vim.log.levels.ERROR)
      return
    end

    local label_name = args[1]
    local layer_name = args[2] -- nil if not provided

    -- Check if this is a range command
    if opts.range == 2 then
      -- Range was specified (e.g., :5,10FAAnnotate label)
      annotations.annotate_range(opts.line1, opts.line2, label_name, layer_name)
    elseif opts.range == 1 then
      -- Single line range (e.g., :5FAAnnotate label)
      annotations.annotate_line(opts.line1, label_name, layer_name)
    else
      -- No range, use current line
      local line_num = vim.fn.line(".")
      annotations.annotate_line(line_num, label_name, layer_name)
    end
  end, {
    nargs = "+",
    range = true,
    complete = M.complete_label_and_layer,
    desc = "Annotate current line or range with label and optional layer"
  })

  vim.api.nvim_create_user_command("FARemoveAnnotation", function(opts)
    local line_num = vim.fn.line(".")
    local label_name = opts.args
    if label_name == "" then
      vim.notify("Usage: FARemoveAnnotation <label_name>", vim.log.levels.ERROR)
      return
    end
    annotations.remove_annotation(line_num, label_name)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    desc = "Remove annotation from current line"
  })

  vim.api.nvim_create_user_command("FAToggleAnnotation", function(opts)
    local line_num = vim.fn.line(".")
    local label_name = opts.args
    if label_name == "" then
      vim.notify("Usage: FAToggleAnnotation <label_name>", vim.log.levels.ERROR)
      return
    end
    annotations.toggle_annotation(line_num, label_name)
  end, {
    nargs = 1,
    complete = M.complete_labels,
    desc = "Toggle annotation on current line"
  })

  vim.api.nvim_create_user_command("FAClearLayer", function(opts)
    local layer_name = opts.args ~= "" and opts.args or nil
    annotations.clear_all_annotations(layer_name)
  end, {
    nargs = "?",
    complete = M.complete_layers,
    desc = "Clear all annotations in layer"
  })

  -- Visual mode annotation
  vim.api.nvim_create_user_command("FAAnnotateSelection", function(opts)
    local args = vim.split(opts.args, " ", { plain = true })

    if #args < 1 or #args > 2 then
      vim.notify("Usage: FAAnnotateSelection <label_name> [layer_name]", vim.log.levels.ERROR)
      return
    end

    local label_name = args[1]
    local layer_name = args[2] -- nil if not provided

    annotations.annotate_selection(label_name, layer_name)
  end, {
    nargs = "+",
    complete = M.complete_label_and_layer,
    range = true,
    desc = "Annotate selected lines with label and optional layer"
  })

  -- Export commands
  vim.api.nvim_create_user_command("FAExportHTML", function(opts)
    local filename = opts.args ~= "" and opts.args or nil
    export.export_to_html(filename)
  end, {
    nargs = "?",
    desc = "Export annotations to HTML"
  })

  vim.api.nvim_create_user_command("FAShowStats", function()
    M.show_annotation_stats()
  end, {
    desc = "Show annotation statistics"
  })

  vim.api.nvim_create_user_command("FAShowAllLayers", function()
    require("file-annotator.highlights").refresh_buffer_all_layers()
    vim.notify("Showing annotations from all visible layers", vim.log.levels.INFO)
  end, {
    desc = "Show annotations from all visible layers"
  })

  vim.api.nvim_create_user_command("FAShowCurrentLayer", function()
    require("file-annotator.highlights").refresh_buffer()
    local state = require("file-annotator").state
    local layer_name = state.current_layer or "none"
    vim.notify("Showing annotations from current layer only: " .. layer_name, vim.log.levels.INFO)
  end, {
    desc = "Show annotations from current layer only"
  })

  -- Quick annotation commands (for common workflows)
  vim.api.nvim_create_user_command("FAQuickSetup", function()
    M.quick_setup()
  end, {
    desc = "Quick setup with default layers and labels"
  })

end

function M.complete_layers(arg_lead, cmd_line, cursor_pos)
  local state = require("file-annotator").state
  local layer_names = {}
  for name, _ in pairs(state.layers) do
    if vim.startswith(name, arg_lead) then
      table.insert(layer_names, name)
    end
  end
  return layer_names
end

function M.complete_labels(arg_lead, cmd_line, cursor_pos)
  local state = require("file-annotator").state

  -- If we have a current layer, prioritize its labels
  local label_names = {}

  if state.current_layer and state.layers[state.current_layer] then
    for name, _ in pairs(state.layers[state.current_layer].labels) do
      if vim.startswith(name, arg_lead) then
        table.insert(label_names, name)
      end
    end
  end

  -- Also include labels from other layers (but avoid duplicates for completion clarity)
  for layer_name, layer in pairs(state.layers) do
    if layer_name ~= state.current_layer then
      for label_name, _ in pairs(layer.labels) do
        if vim.startswith(label_name, arg_lead) and not vim.tbl_contains(label_names, label_name) then
          table.insert(label_names, label_name)
        end
      end
    end
  end

  return label_names
end

function M.complete_label_and_layer(arg_lead, cmd_line, cursor_pos)
  local state = require("file-annotator").state
  local args = vim.split(cmd_line, " ", { plain = true })

  -- Remove the command name
  table.remove(args, 1)

  -- If we're completing the first argument (label), show all labels from all layers
  if #args <= 1 then
    local label_names = {}
    for layer_name, layer in pairs(state.layers) do
      for label_name, _ in pairs(layer.labels) do
        if vim.startswith(label_name, arg_lead) and not vim.tbl_contains(label_names, label_name) then
          table.insert(label_names, label_name)
        end
      end
    end
    return label_names
  end

  -- If we're completing the second argument (layer), show all layer names
  if #args == 2 then
    local layer_names = {}
    for name, _ in pairs(state.layers) do
      if vim.startswith(name, arg_lead) then
        table.insert(layer_names, name)
      end
    end
    return layer_names
  end

  return {}
end

function M.show_layers_info()
  local layer_list = layers.list_layers()

  if #layer_list == 0 then
    vim.notify("No layers created yet", vim.log.levels.INFO)
    return
  end

  local lines = {"File Annotator Layers:", ""}

  for _, layer in ipairs(layer_list) do
    local status_indicators = {}
    if layer.current then table.insert(status_indicators, "CURRENT") end
    if layer.visible then table.insert(status_indicators, "VISIBLE") else table.insert(status_indicators, "HIDDEN") end

    local status = #status_indicators > 0 and (" [" .. table.concat(status_indicators, ", ") .. "]") or ""
    table.insert(lines, string.format("• %s%s - %d labels", layer.name, status, layer.label_count))
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.show_annotation_stats()
  local stats = export.export_layer_stats()

  local lines = {"Annotation Statistics:", ""}
  lines[#lines + 1] = string.format("Total annotations: %d", stats.total_annotations)
  lines[#lines + 1] = string.format("Total layers: %d", vim.tbl_count(stats.layers))
  lines[#lines + 1] = ""

  for layer_name, layer_stats in pairs(stats.layers) do
    lines[#lines + 1] = string.format("Layer '%s': %d lines", layer_name, layer_stats.total_lines)
    for label_name, count in pairs(layer_stats.labels) do
      lines[#lines + 1] = string.format("  • %s: %d lines", label_name, count)
    end
    lines[#lines + 1] = ""
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.quick_setup()
  -- Create default layers
  layers.create_layer("review")
  layers.create_layer("issues")
  layers.create_layer("notes")

  -- Add default labels to review layer
  layers.set_current_layer("review")
  layers.add_label("review", "good", "#4ECDC4")
  layers.add_label("review", "needs_work", "#FF6B6B")
  layers.add_label("review", "unclear", "#FFEAA7")

  -- Add default labels to issues layer
  layers.set_current_layer("issues")
  layers.add_label("issues", "bug", "#FF4757")
  layers.add_label("issues", "security", "#FF3838")
  layers.add_label("issues", "performance", "#FF9F43")

  -- Add default labels to notes layer
  layers.set_current_layer("notes")
  layers.add_label("notes", "important", "#5F27CD")
  layers.add_label("notes", "todo", "#00D2D3")
  layers.add_label("notes", "question", "#FF9FF3")

  -- Set review as current layer
  layers.set_current_layer("review")

  vim.notify("Quick setup complete! Created 3 layers with default labels.", vim.log.levels.INFO)
end

-- Key mapping helpers
function M.setup_keymaps()
  -- Example keymaps - users can customize these
  local opts = { noremap = true, silent = true }

  -- Quick annotation with number keys (requires current layer to have numbered labels)
  for i = 1, 9 do
    vim.keymap.set("n", "<leader>a" .. i, function()
      local state = require("file-annotator").state
      if not state.current_layer then
        vim.notify("No current layer set", vim.log.levels.ERROR)
        return
      end

      local labels = {}
      for name, _ in pairs(state.layers[state.current_layer].labels) do
        table.insert(labels, name)
      end
      table.sort(labels)

      if labels[i] then
        local line_num = vim.fn.line(".")
        annotations.toggle_annotation(line_num, labels[i])
      end
    end, opts)
  end

  -- Layer switching
  vim.keymap.set("n", "<leader>al", function()
    M.show_layers_info()
  end, opts)

  -- Export
  vim.keymap.set("n", "<leader>ae", function()
    export.export_to_html()
  end, opts)
end


return M