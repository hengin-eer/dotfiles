call plug#begin()
" status line
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" fuzzy finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" vim-lsp
Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'

call plug#end()

" Official Plugin
packadd! editorconfig

" タブラインの有効化
let g:airline#extensions#tabline#enabled = 1
" Smarter tab line有効化
" let g:airline#extensions#tabline#enabled = 1
" powerline font入れないと若干ダサい
" let g:airline_powerline_fonts = 1
" vim-airline-themesが必要
let g:airline_theme='behelit'

" fzf settings
let $FZF_DEFAULT_OPTS="--layout=reverse"
let $FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git/**'"
let g:fzf_layout = {'up':'~90%', 'window': { 'width': 0.8, 'height': 0.8,'yoffset':0.5,'xoffset': 0.5, 'border': 'sharp' } }
let mapleader = "\<Space>"

" base config
" -----------
set encoding=utf-8
set termencoding=utf-8
set fileencoding=utf-8
set number
set virtualedit=block
set wildmenu
set autoread
set nobackup
set noswapfile

" cursor settings
set cursorline
set cursorcolumn

" display settings
set showmatch matchtime=1
set showmatch
set showcmd
set helpheight=999
set visualbell
set hlsearch
set listchars=tab:^\ ,trail:~ " 行末のスペースを可視化
" indent settings
set expandtab
set shiftwidth=2
set softtabstop=2
set tabstop=2
set guioptions+=a
set clipboard=unnamed,autoselect
set smartindent
set title
syntax on
color habamax

" key map
" -------
inoremap <silent> jj <ESC>
inoremap <silent> ｊｊ <ESC>
nnoremap <ESC><ESC> :noh<CR>
" fzf(fuzzy finder)
" -----------------
" search files
nnoremap <silent> <leader>f :Files<CR>
" Git files(`git ls-files`)
nnoremap <silent> <leader>g :GFiles<CR>
" Git files(`git status`)
nnoremap <silent> <leader>G :GFiles?<CR>
" Open buffers
nnoremap <silent> <leader>b :Buffers<CR>
" `v:oldfiles` and open buffers
nnoremap <silent> <leader>h :History<CR>
" use grep search
nnoremap <silent> <leader>r :Rg<CR>
" ailine
" ------
" カーソルキーでbuffer移動
nnoremap <Left> :bp<CR>
nnoremap <Right> :bn<CR>
