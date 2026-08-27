return {
  "rose-pine/neovim",
  name = "rose-pine",
  priority = 5000,
  lazy = false,
  config = function()
    require("rose-pine").setup({
      styles = {
        transparency = true,
      },
    })
    vim.cmd([[
			colorscheme rose-pine
			hi SpecialKey    guifg=#61AFEF
			hi SpecialKeyWin guifg=#61AFEF
			set winhighlight=SpecialKey:SpecialKeyWin
		]])
  end
}
