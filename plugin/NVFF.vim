if !has('nvim')
  finish
endif

" The key sequence that should activate the buffer browser. The default is ^F.
"   Enter the key sequence in a single quoted string, exactly as you would use
"   it in a map command.
"

if !exists("g:vffFindActKeySeq")
  let vffFindActKeySeq = '<C-F>'
endif

if !exists("g:vffGrepActKeySeq")
  let vffGrepActKeySeq = '<C-G>'
endif

if !exists("g:vffSearchActKeySeq")
  let vffSearchActKeySeq = '<C-S>'
endif

if !exists("g:vffChooseConfigKeySeq")
  let vffChooseConfigKeySeq = '<C-Q>'
endif

" The name of the browser. The default is "/---Select File---", but you can
"   change the name at your will. A leading '/' is advised if you change
"   directories from with in vim.
let vffWindowName = '/---\ Select\ File\ ---'

" A non-zero value for the variable vffRemoveBrowserBuffer means that after
"   the selection is made, the buffer that belongs to the browser should be
"   deleted. But this is not advisable as vim doesn't reuse the buffer numbers
"   that are no longer used. The default value is 0, i.e., reuse a single
"   buffer. This will avoid creating lots of gaps and quickly reach a large
"   buffer numbers for the new buffers created.
let vffRemoveBrowserBuffer = 1

"
" A non-zero value for the variable highlightOnlyFilename will highlight only
"   the filename instead of the whole path. The default value is 0.
let highlightOnlyFilename = 0

" Your can configure a delay in between when typing stops and results list.
"   To enable the delay, add to your .vimrc:
"      let g:vff_debounce = 1
"   The default is 100 ms. To change it to 50 ms, add to your .vimrc:
"      let g:vff_debounce_delay = 50
"
if exists("g:vff_debounce")
  if exists("g:vff_debounce_delay")
    let g:vff_refreshdelay = g:vff_debounce_delay
  else
    let g:vff_refreshdelay = 100
  endif
endif

"
" END configuration.
"

function! VffSetupActivationKey ()
  exec 'nnoremap ' . g:vffFindActKeySeq . ' :call VffListBufs ("find")<CR>'
  exec 'vnoremap ' . g:vffFindActKeySeq . ' :call VffListBufs ("find")<CR>'
  exec 'nnoremap ' . g:vffGrepActKeySeq . ' :call VffListBufs ("grep")<CR>'
  exec 'vnoremap ' . g:vffGrepActKeySeq . ' :call VffListBufs ("grep")<CR>'
  exec 'nnoremap ' . g:vffSearchActKeySeq . ' :call VffSearch ("normal")<CR>'
  exec 'vnoremap ' . g:vffSearchActKeySeq . ' :call VffSearch ("visual")<CR>'
  exec 'nnoremap ' . g:vffChooseConfigKeySeq . ' :call VffChooseConfig()<CR>'
endfunction

function! VffSetupDeActivationKey ()
  exec 'nnoremap ' . g:vffFindActKeySeq . ' :call VffDeActivate ("find")<CR>'
  exec 'vnoremap ' . g:vffFindActKeySeq . ' :call VffDeActivate ("find")<CR>'
  exec 'nnoremap ' . g:vffGrepActKeySeq . ' :call VffDeActivate ("grep")<CR>'
  exec 'vnoremap ' . g:vffGrepActKeySeq . ' :call VffDeActivate ("grep")<CR>'
  exec 'nnoremap ' . g:vffSearchActKeySeq . ' :call VffDeActivate ("grep")<CR>'
  exec 'vnoremap ' . g:vffSearchActKeySeq . ' :call VffDeActivate ("grep")<CR>'
endfunction

call VffSetupActivationKey ()

let g:vff_query = ""
let g:vff_line = #{ find: -1, grep: -1 }
let g:vff_path = ""
let g:vff_status = ""

function! VffListBufs (mode)
  let g:vff_mode = a:mode
  let g:vff_savetimeoutlen = &timeoutlen
  let g:vff_origwin = winnr()
  let l:saveReport = &report
  let &timeoutlen=0
  let &report=10000
  silent! exec ":new " . g:vffWindowName
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  let g:vff_vffwin = winnr()
  if g:vff_mode == 'find'
    syn match Title "Find File:.*"
  else
    syn match Title "Find Content:.*"
  endif
  syn match Title "----------------*"
  hi CursorLine   cterm=NONE ctermbg=darkblue ctermfg=white
  setlocal cc=
  let &report = l:saveReport
  0,$d_
  let l:ret = VFFEnterSync(g:vff_mode)
  if !empty(l:ret)
    let g:vff_path = (l:ret)[0]
    aug ListFiles
      exec "au WinEnter " . g:vffWindowName . " call VffSetupSelect ()"
      exec "au WinLeave " . g:vffWindowName . " call VffUnsetupSelect ()"
      exec "au BufLeave " . g:vffWindowName . " call VffClearSetup ()"
    aug END
    setlocal cursorline
    call VffSetupSelect ()
    call append(0, 'VimFastFind: Ctrl-F for file mode, Ctrl-G for grep mode')
    call append(1, '<C-F>/<C-G> again to quit, <UP>/<DOWN> or Alt-J/Alt-K to move, <ENTER> to select')
    call append(2, '--------------------------------------------------------------------------------')
    call append(3, 'Root: ' . g:vff_path . " [ " . g:vff_status . " ]")
    call append(4, '')
    if g:vff_mode == 'grep'
      call append(5, 'Find Content: ' . (l:ret)[1])
    else
      call append(5, 'Find File: ' . (l:ret)[1])
    endif
    call append(6, '')
    call VFFRefresh(g:vff_mode)
  else
    call VffSetupBadSelect ()
    call append(0, "ERROR: No .vff file found!")
    call append(1, "")
    call append(2, "Hit ESCAPE or ENTER to close this window")
  endif
  set nomodified
  call VffRestoreLineNumber()
endfunction

function! VffSearch (vimMode)
  if a:vimMode == 'visual'
    let s:query = VffGetSelection ()
  else
    let s:query = expand ('<cword>')
  endif
  call VFFTextClearSync("grep")
  call VFFTextAppendSync("grep", s:query)
  call VffListBufs ("grep")
endfunction

function! VffGetSelection()
  return getline('.')[col("'<")-1:col("'>")-1]
endfunction

function! VffClearSetup ()
  aug ListFiles
    exec "au! WinEnter " . g:vffWindowName
    exec "au! WinLeave " . g:vffWindowName
    exec "au! BufLeave " . g:vffWindowName
  aug END
  call VffUnsetupSelect ()
endfunction

function! VffSetupBadSelect ()
  if ! exists ("g:VffSetup")
    nnoremap <buffer> <CR>     :call VffQuit()<CR>
    nnoremap <buffer> <C-C>    :call VffQuit()<CR>
    " nnoremap <buffer> <ESC>    :call VffQuit()<CR>
    nnoremap <buffer> q        :call VffQuit()<CR>
    call VffSetupDeActivationKey ()
    let g:VffSetup = 1
  endif
endfunction

function! VffSetupSelect ()
  if ! exists ("g:VffSetup")
    set nofoldenable
    nnoremap <buffer> <CR>     :call VffSelectCurrentBuffer()<CR>
    nnoremap <buffer> <C-C>    :call VffQuit()<CR>
    " nnoremap <buffer> <ESC>    :call VffQuit()<CR>
    nnoremap <buffer> <SPACE>  :call VffText(' ')<CR>
    nnoremap <buffer> a        :call VffText('a')<CR>
    nnoremap <buffer> b        :call VffText('b')<CR>
    nnoremap <buffer> c        :call VffText('c')<CR>
    nnoremap <buffer> d        :call VffText('d')<CR>
    nnoremap <buffer> e        :call VffText('e')<CR>
    nnoremap <buffer> f        :call VffText('f')<CR>
    nnoremap <buffer> g        :call VffText('g')<CR>
    nnoremap <buffer> h        :call VffText('h')<CR>
    nnoremap <buffer> i        :call VffText('i')<CR>
    nnoremap <buffer> j        :call VffText('j')<CR>
    nnoremap <buffer> k        :call VffText('k')<CR>
    nnoremap <buffer> l        :call VffText('l')<CR>
    nnoremap <buffer> m        :call VffText('m')<CR>
    nnoremap <buffer> n        :call VffText('n')<CR>
    nnoremap <buffer> o        :call VffText('o')<CR>
    nnoremap <buffer> p        :call VffText('p')<CR>
    nnoremap <buffer> q        :call VffText('q')<CR>
    nnoremap <buffer> r        :call VffText('r')<CR>
    nnoremap <buffer> s        :call VffText('s')<CR>
    nnoremap <buffer> t        :call VffText('t')<CR>
    nnoremap <buffer> u        :call VffText('u')<CR>
    nnoremap <buffer> v        :call VffText('v')<CR>
    nnoremap <buffer> w        :call VffText('w')<CR>
    nnoremap <buffer> x        :call VffText('x')<CR>
    nnoremap <buffer> y        :call VffText('y')<CR>
    nnoremap <buffer> z        :call VffText('z')<CR>
    nnoremap <buffer> A        :call VffText('A')<CR>
    nnoremap <buffer> B        :call VffText('B')<CR>
    nnoremap <buffer> C        :call VffText('C')<CR>
    nnoremap <buffer> D        :call VffText('D')<CR>
    nnoremap <buffer> E        :call VffText('E')<CR>
    nnoremap <buffer> F        :call VffText('F')<CR>
    nnoremap <buffer> G        :call VffText('G')<CR>
    nnoremap <buffer> H        :call VffText('H')<CR>
    nnoremap <buffer> I        :call VffText('I')<CR>
    nnoremap <buffer> J        :call VffText('J')<CR>
    nnoremap <buffer> K        :call VffText('K')<CR>
    nnoremap <buffer> L        :call VffText('L')<CR>
    nnoremap <buffer> M        :call VffText('M')<CR>
    nnoremap <buffer> N        :call VffText('N')<CR>
    nnoremap <buffer> O        :call VffText('O')<CR>
    nnoremap <buffer> P        :call VffText('P')<CR>
    nnoremap <buffer> Q        :call VffText('Q')<CR>
    nnoremap <buffer> R        :call VffText('R')<CR>
    nnoremap <buffer> S        :call VffText('S')<CR>
    nnoremap <buffer> T        :call VffText('T')<CR>
    nnoremap <buffer> U        :call VffText('U')<CR>
    nnoremap <buffer> V        :call VffText('V')<CR>
    nnoremap <buffer> W        :call VffText('W')<CR>
    nnoremap <buffer> X        :call VffText('X')<CR>
    nnoremap <buffer> Y        :call VffText('Y')<CR>
    nnoremap <buffer> Z        :call VffText('Z')<CR>
    nnoremap <buffer> 0        :call VffText('0')<CR>
    nnoremap <buffer> 1        :call VffText('1')<CR>
    nnoremap <buffer> 2        :call VffText('2')<CR>
    nnoremap <buffer> 3        :call VffText('3')<CR>
    nnoremap <buffer> 4        :call VffText('4')<CR>
    nnoremap <buffer> 5        :call VffText('5')<CR>
    nnoremap <buffer> 6        :call VffText('6')<CR>
    nnoremap <buffer> 7        :call VffText('7')<CR>
    nnoremap <buffer> 8        :call VffText('8')<CR>
    nnoremap <buffer> 9        :call VffText('9')<CR>
    nnoremap <buffer> `        :call VffText('`')<CR>
    nnoremap <buffer> :        :call VffText(':')<CR>
    nnoremap <buffer> .        :call VffText('.')<CR>
    nnoremap <buffer> ,        :call VffText(',')<CR>
    nnoremap <buffer> ?        :call VffText('?')<CR>
    nnoremap <buffer> <        :call VffText('<')<CR>
    nnoremap <buffer> >        :call VffText('>')<CR>
    nnoremap <buffer> /        :call VffText('/')<CR>
    nnoremap <buffer> \        :call VffText('\')<CR>
    nnoremap <buffer> !        :call VffText('!')<CR>
    nnoremap <buffer> @        :call VffText('@')<CR>
    nnoremap <buffer> #        :call VffText('#')<CR>
    nnoremap <buffer> $        :call VffText('$')<CR>
    nnoremap <buffer> %        :call VffText('%')<CR>
    nnoremap <buffer> ^        :call VffText('^')<CR>
    nnoremap <buffer> &        :call VffText('&')<CR>
    nnoremap <buffer> *        :call VffText('*')<CR>
    nnoremap <buffer> (        :call VffText('(')<CR>
    nnoremap <buffer> )        :call VffText(')')<CR>
    nnoremap <buffer> [        :call VffText('[')<CR>
    nnoremap <buffer> {        :call VffText('{')<CR>
    nnoremap <buffer> ]        :call VffText(']')<CR>
    nnoremap <buffer> }        :call VffText('}')<CR>
    nnoremap <buffer> -        :call VffText('-')<CR>
    nnoremap <buffer> _        :call VffText('_')<CR>
    nnoremap <buffer> +        :call VffText('+')<CR>
    nnoremap <buffer> =        :call VffText('=')<CR>
    nnoremap <buffer> "        :call VffText('"')<CR>
    nnoremap <buffer> ~        :call VffText('~')<CR>
    nnoremap <buffer> '        :call VffText("'")<CR>
    nnoremap <buffer> \|       :call VffText("\|")<CR>
    nnoremap <buffer> <BS>     :call VffBackspace()<CR>
    nnoremap <buffer> <C-L>    :call VffClear()<CR>
    nnoremap <buffer> <M-J>    :call VffDown(1)<CR>
    nnoremap <buffer> <M-K>    :call VffUp(1)<CR>
    nnoremap <buffer> <A-J>    :call VffDown(1)<CR>
    nnoremap <buffer> <A-K>    :call VffUp(1)<CR>
    nnoremap <buffer> ∆        :call VffDown(1)<CR>
    nnoremap <buffer> ˚        :call VffUp(1)<CR>
    nnoremap <buffer> j      :call VffDown(1)<CR>
    nnoremap <buffer> k      :call VffUp(1)<CR>
    nnoremap <buffer> <C-DOWN> :call VffDown(1)<CR>
    nnoremap <buffer> <C-UP>   :call VffUp(1)<CR>
    nnoremap <buffer> <A-DOWN> :call VffDown(1)<CR>
    nnoremap <buffer> <A-UP>   :call VffUp(1)<CR>
    nnoremap <buffer> <S-DOWN> :call VffDown(1)<CR>
    nnoremap <buffer> <S-UP>   :call VffUp(1)<CR>
    nnoremap <buffer> <C-J>    :call VffDown(1)<CR>
    nnoremap <buffer> <C-K>    :call VffUp(1)<CR>
    nnoremap <buffer> <C-D>    :call VffDown(10)<CR>
    nnoremap <buffer> <C-U>    :call VffUp(10)<CR>
    nnoremap <buffer> <DOWN>   :call VffDown(1)<CR>
    nnoremap <buffer> <UP>     :call VffUp(1)<CR>
    cabbr <buffer> w q
    cabbr <buffer> wq q
    call VffSetupDeActivationKey ()
    let g:VffSetup = 1
  endif
endfunction

if exists("g:vff_refreshdelay")
  exec "set updatetime=" . g:vff_refreshdelay
  " this autocommand fires when a char hasn't been typed in 'updatetime' ms, in normal mode
  autocmd CursorHold * :call VffRefresh()
endif

function! VffRefresh ()
  if exists("g:vff_needrefresh")
    if exists("g:vff_refreshdelay")
      call VFFRefresh(g:vff_mode)
    endif
    unlet g:vff_needrefresh
  endif
endfunction

" updates the entry line immediately but don't refresh the results until the next CursorHold event
function! VffText (ch)
  let g:vff_query = VFFTextAppendSync(g:vff_mode, a:ch)
  call VffSaveLineNumber()
  if g:vff_mode == 'grep'
    call setline(6, 'Find Content: ' . g:vff_query)
  else
    call setline(6, 'Find File: ' . g:vff_query)
  endif
  echo ""
  if exists("g:vff_refreshdelay")
    let g:vff_needrefresh = 1
  else
    call VFFRefresh(g:vff_mode)
  endif
endfunction

function! VffLines (lines)
  silent! 7,$d
  let l:lines = split(a:lines, "\n")
  if len(l:lines) > 0
    call append(6, l:lines)
  else
    call append(6, "")
  endif
  call VffRestoreLineNumber()
endfunction

function! VffStatus (status)
  let g:vff_status = a:status
  call setline(4, 'Root: ' . g:vff_path . " [ " . g:vff_status . " ]")
endfunction

function! VffSaveLineNumber ()
  let g:vff_line[g:vff_mode] = line(".")
endfunction

function! VffRestoreLineNumber ()
  if g:vff_line[g:vff_mode] >= 7
    exec g:vff_line[g:vff_mode]
  else
    exec 7
  endif
endfunction

function! VffWaiting (ch)
  call setline(4, 'Root: ' . g:vff_path . " [ " . g:vff_status . " ] " . a:ch)
endfunction

" updates the entry line immediately but don't refresh the results until the next CursorHold event
function! VffBackspace ()
  let g:vff_query = VFFTextBackspaceSync(g:vff_mode)
  if g:vff_query == v:null
    let g:vff_query = ''
  endif
  call VffSaveLineNumber()
  if g:vff_mode == 'grep'
    call setline(6, 'Find Content: ' . g:vff_query)
  else
    call setline(6, 'Find File: ' . g:vff_query)
  endif
  echo ""
  if exists("g:vff_refreshdelay")
    let g:vff_needrefresh = 1
  else
    call VFFRefresh(g:vff_mode)
  endif
endfunction

" updates the entry and results immediately
function! VffClear ()
  let g:vff_query = VFFTextClearSync(g:vff_mode)
  if g:vff_query == v:null
    let g:vff_query = ''
  endif
  call VffSaveLineNumber()
  if g:vff_mode == 'grep'
    call setline(6, 'Find Content: ' . g:vff_query)
  else
    call setline(6, 'Find File: ' . g:vff_query)
  endif
  call VffLines('')
  echo ""
endfunction

function! VffUp(v)
  let l:line = line(".")
  if l:line - a:v > 7
    silent! exec "normal! " . a:v . "k"
  else
    7
  endif
  call VffSaveLineNumber()
  echo ""
endfunction

function! VffDown(v)
  silent! exec "normal! " . a:v . "j"
  call VffSaveLineNumber()
  echo ""
endfunction

function! VffUnsetupSelect ()
  if exists ("g:VffSetup")
    call VffSetupActivationKey ()
    unlet g:VffSetup
  endif
endfunction

function! VffSelectCurrentBuffer ()
  let &timeoutlen = g:vff_savetimeoutlen
  let l:myBufNr = bufnr ("%")
  let l:line = getline(".")
  let l:lineNr = line(".")
  quit
  if l:line != "" && l:lineNr >= 7
    let l:path = VFFRelativePathSync(getcwd(), '/' . substitute(l:line, "([0-9]\\+):.*", "", ""))
    silent exec "edit " . fnameescape(l:path)
    if g:vff_mode == 'grep'
      let l:offset = substitute(l:line, "^[^(]*(\\([0-9]\\+\\)):.*", "\\1", "")
      exec 'goto ' . l:offset
      if (foldclosed('.') != -1)
        foldopen!
      endif
    endif
  endif
  if g:vffRemoveBrowserBuffer
    silent! exec "bd " . l:myBufNr
  endif
endfunction

function! VffQuit ()
  let l:myBufNr = bufnr ("%")
  set nomodified
  silent! exec "bd " . l:myBufNr
  call VffUnsetupSelect()
  let &timeoutlen = g:vff_savetimeoutlen
endfunction

function! VffDeActivate (mode)
  call VffQuit()
  if a:mode != g:vff_mode
    " Toggle between find/grep modes
    call VffListBufs (a:mode)
  endif
endfunction

function! VffChooseConfig ()
  call fzf#run({'source': 'ls .vff*', 'options': '--multi', 'sink': function("VffChangeConfig")})
endfunction

function! VffChangeConfig (configPath)
  call VFFUpdateVffPath(getcwd() . "/" . a:configPath)
endfunction
