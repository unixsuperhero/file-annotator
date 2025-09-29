local M = {}

M.config = {
  default_colors = {
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
    "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
  },
  export_dir = vim.fn.stdpath("data") .. "/file-annotator/exports"
}

M.state = {
  layers = {},
  current_layer = nil,
  annotations = {},
  namespaces = {}
}

local function ensure_export_dir()
  vim.fn.mkdir(M.config.export_dir, "p")
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
  ensure_export_dir()

  require("file-annotator.commands").setup()
  require("file-annotator.highlights").setup()
end

return M
