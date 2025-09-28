# File Annotator - Neovim Plugin

A powerful Neovim plugin for annotating files with multiple layers and labels, perfect for code review and line-by-line analysis. Generate beautiful HTML exports with color-coded annotations.

## Features

- **Multi-layer annotation system** - Organize annotations into different layers (e.g., "review", "issues", "notes")
- **Customizable labels** - Create, rename, and remove labels with custom colors
- **Visual highlighting** - See annotations directly in your editor with background colors
- **HTML export** - Generate professional HTML reports with color-coded lines
- **Layer management** - Show/hide layers, switch between them easily
- **Range selection** - Annotate multiple lines at once
- **Intuitive commands** - Easy-to-use Vim commands for all operations

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/file-annotator",
  config = function()
    require("file-annotator").setup({
      -- Optional configuration
      default_colors = {
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9"
      },
      export_dir = vim.fn.stdpath("data") .. "/file-annotator/exports"
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/file-annotator",
  config = function()
    require("file-annotator").setup()
  end
}
```

## Quick Start

### Auto-Create Workflow (Recommended)
1. **Start annotating immediately**: `:FAAnnotate good review` (creates both label and layer)
2. **Continue annotating**: `:FAAnnotate bug issues`, `:FAAnnotate todo notes`
3. **Export to HTML**: `:FAExportHTML` to generate a report

### Traditional Workflow
1. **Quick Setup**: Run `:FAQuickSetup` to create default layers and labels
2. **Annotate a line**: Place cursor on a line and run `:FAAnnotate good`
3. **Export to HTML**: Run `:FAExportHTML` to generate a report

## Auto-Creation Feature

The plugin automatically creates layers and labels when they don't exist:

- `:FAAnnotate <label> <layer>` - Creates both label and layer if needed
- `:FAAnnotateSelection <label> <layer>` - Same for selected lines
- Auto-assigns colors from the default color palette
- Notifies you when new items are created

## Commands

### Layer Management

| Command | Description |
|---------|-------------|
| `:FACreateLayer <name>` | Create a new annotation layer |
| `:FADeleteLayer <name>` | Delete an annotation layer |
| `:FARenameLayer <old> <new>` | Rename a layer |
| `:FASetLayer <name>` | Set the current active layer |
| `:FAToggleLayer <name>` | Show/hide a layer |
| `:FAListLayers` | List all layers with status |

### Label Management

| Command | Description |
|---------|-------------|
| `:FAAddLabel <name> [color]` | Add a label to current layer |
| `:FARemoveLabel <name>` | Remove a label from current layer |
| `:FARenameLabel <old> <new>` | Rename a label in current layer |

### Annotation

| Command | Description |
|---------|-------------|
| `:FAAnnotate <label> [layer]` | Annotate current line with label (auto-creates if needed) |
| `:FARemoveAnnotation <label>` | Remove annotation from current line |
| `:FAToggleAnnotation <label>` | Toggle annotation on current line |
| `:FAAnnotateSelection <label> [layer]` | Annotate selected lines (auto-creates if needed) |
| `:FAClearLayer [layer]` | Clear all annotations in layer |

### Export & Info

| Command | Description |
|---------|-------------|
| `:FAExportHTML [filename]` | Export annotations to HTML |
| `:FAShowStats` | Show annotation statistics |
| `:FAQuickSetup` | Quick setup with default layers |

## Usage Examples

### Basic Workflow

```vim
\" Auto-create workflow (recommended)
\" Directly annotate with layer specification - creates both label and layer if needed
:FAAnnotate good review
:FAAnnotate needs_work review
:FAAnnotate bug issues
:FAAnnotate security issues

\" Manual workflow (traditional)
\" Create layers for different purposes
:FACreateLayer review
:FACreateLayer issues
:FACreateLayer notes

\" Add labels to review layer
:FASetLayer review
:FAAddLabel good #4ECDC4
:FAAddLabel needs_work #FF6B6B
:FAAddLabel unclear #FFEAA7

\" Annotate some lines (uses current layer)
:FAAnnotate good
:FAAnnotate needs_work

\" Export to HTML
:FAExportHTML my_review.html
```

### Code Review Workflow

```vim
\" Simple auto-create workflow (no setup needed!)
\" Just start annotating - layers and labels are created automatically
:FAAnnotate good review          \" Mark good code in review layer
:FAAnnotate needs_work review    \" Mark code that needs improvement
:FAAnnotate unclear review       \" Mark unclear sections

:FAAnnotate bug issues           \" Mark bugs in issues layer
:FAAnnotate security issues      \" Mark security issues

:FAAnnotate important notes      \" Mark important sections in notes layer
:FAAnnotate todo notes           \" Mark TODO items

\" Export comprehensive review
:FAExportHTML code_review_2024_01_15.html

\" Alternative: Traditional workflow with setup
:FAQuickSetup

\" Set layer before annotating (uses current layer)
:FASetLayer review
:FAAnnotate good
:FAAnnotate needs_work

:FASetLayer issues
:FAAnnotate bug
:FAAnnotate security
```

### Multi-line Annotation

```vim
\" Select multiple lines in visual mode, then:
:'<,'>FAAnnotateSelection needs_work review    \" With layer specification
:'<,'>FAAnnotateSelection needs_work           \" Uses current layer
```

## Key Mappings (Optional)

Add these to your configuration for quick access:

```lua
-- Setup key mappings
require("file-annotator.commands").setup_keymaps()

-- Or create custom mappings:
vim.keymap.set("n", "<leader>aa", ":FAAnnotate ", { desc = "Annotate line" })
vim.keymap.set("n", "<leader>al", ":FAListLayers<CR>", { desc = "List layers" })
vim.keymap.set("n", "<leader>ae", ":FAExportHTML<CR>", { desc = "Export HTML" })
vim.keymap.set("v", "<leader>as", ":FAAnnotateSelection ", { desc = "Annotate selection" })
```

## HTML Export Features

The HTML export creates a professional report with:

- **Color-coded lines** - Each annotation shows as background color
- **Interactive legend** - Shows all layers and labels with colors
- **Layer controls** - Toggle layer visibility in the export
- **Gradient overlays** - Multiple annotations on same line create gradients
- **Metadata** - Export timestamp and source file information
- **Responsive design** - Works well on different screen sizes

## Configuration

```lua
require("file-annotator").setup({
  -- Default colors for labels (used when no color specified)
  default_colors = {
    "#FF6B6B",  -- Red
    "#4ECDC4",  -- Teal
    "#45B7D1",  -- Blue
    "#96CEB4",  -- Green
    "#FFEAA7",  -- Yellow
    "#DDA0DD",  -- Plum
    "#98D8C8",  -- Mint
    "#F7DC6F",  -- Light yellow
    "#BB8FCE",  -- Light purple
    "#85C1E9"   -- Light blue
  },

  -- Directory where HTML exports are saved
  export_dir = vim.fn.stdpath("data") .. "/file-annotator/exports"
})
```

## Use Cases

- **Code Reviews** - Systematically review and annotate code
- **Learning** - Mark different concepts while studying code
- **Bug Hunting** - Track issues and their severity
- **Documentation** - Create visual guides for codebases
- **Teaching** - Prepare annotated examples for students
- **Auditing** - Security or compliance reviews

## Tips

1. **Use meaningful layer names** - "security", "performance", "style", etc.
2. **Consistent labeling** - Establish a labeling convention for your team
3. **Color coding** - Use similar colors for related concepts
4. **Export regularly** - Create timestamped exports for historical tracking
5. **Layer organization** - Keep related annotations in the same layer

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see LICENSE file for details.