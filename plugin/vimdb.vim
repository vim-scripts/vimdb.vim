" Description: Vim plugin to simulate a simple database
" Last Change: 2008 Jul 21
" Author:      Benjamin Schnitzler <benschni at yahoo dot de>
" License:     This file is placed in the public domain.
"
" WARNING: Look at Warning at line 17
" Recommendation:
" Place the following command into your .vimrc for a better overview:
" au BufRead,BufNewFile *.vim set foldmarker=func,endfunc
" Look_also_at: readme!!!
" 
" TODO:
" Write TODO


"(very) Global Settings and WARNING:
"virtualedit is necessary for some special characters which have not
"bytelength. It may cause Problems with other scripts.
"If you plan to unset it, you have to change the cursor command used 
"in RecordbufMove() and RecordbufMoveI() a bit.
"set virtualedit=all
"Setting was moved into StartDb() due to otherwise beeing always
"applied you open vim - sorry, my mistake.

"if exists("vimdbplugin")
"  finish
"endif
let vimdbplugin = 2

"Autocommands
au BufRead,BufNewFile                *.vimdb   call StartDb()
au CursorMoved,CursorMovedI,BufEnter *.vimdb   call TableChange()
au BufLeave                          *.vimdb   call LeaveDb()

au BufEnter,BufRead                  recordbuf call RecordbufMove()
au BufEnter,BufRead                  recordbuf call EnterRecordbuf()
au CursorMoved                       recordbuf call RecordbufMove()
au InsertEnter                       recordbuf call RecordbufEnterI()
au CursorMovedI                      recordbuf call RecordbufMoveI()
au InsertLeave                       recordbuf call RecordbufLeaveI()
au BufLeave                          recordbuf call LeaveRecordbuf()


func ToggleAutocmd()
  if s:AUTO == 1
    let s:AUTO = 0
    au! CursorMoved,CursorMovedI,BufEnter *.vimdb  
    au! BufRead,BufNewFile                *.vimdb  
    au! BufLeave                          *.vimdb
    au! BufEnter,BufRead                  recordbuf
    au! InsertEnter                       recordbuf
    au! CursorMoved                       recordbuf
    au! CursorMovedI                      recordbuf
    au! InsertLeave                       recordbuf
    au! BufLeave                          recordbuf
  elseif s:AUTO == 0
    au CursorMoved,CursorMovedI,BufEnter *.vimdb   call TableChange()
    au BufRead,BufNewFile                *.vimdb   call StartDb()
    au BufLeave                          *.vimdb   call LeaveDb()
    au BufEnter,BufRead                  recordbuf call EnterRecordbuf()
    au BufEnter,BufRead                  recordbuf call RecordbufMove()
    au InsertEnter                       recordbuf call RecordbufEnterI()
    au CursorMoved                       recordbuf call RecordbufMove()
    au CursorMovedI                      recordbuf call RecordbufMoveI()
    au InsertLeave                       recordbuf call RecordbufLeaveI()
    au BufLeave                          recordbuf call LeaveRecordbuf()
    let s:AUTO = 1
  endif
endfunc


"Autocommand Functions for *.vimdb
func StartDb()
  set virtualedit=all

  let s:AUTO = 1

  let s:DBFILE = bufname("")
  let s:DBPOS = getpos(".")

  let s:CUTLIST = []

  let s:DBHEAD = []
  let s:LONGEST = 0
  let s:BLONGEST = 0
  let s:FIRSTENTRY = 0

  let s:TABMODE = 0
  let s:TABBUF = ""
  let s:FIRSTTAB = 0

  call RefreshHeader()

  setlocal tw=0
  setlocal bufhidden=hide

  nnoremap <buffer> o  :call AddTableRow("o")<CR>
  nnoremap <buffer> O  :call AddTableRow("O")<CR>

  nnoremap <buffer> <TAB> :call IntelligentTab(0)<CR>

  badd recordbuf
  bnext

  setlocal tw=0
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile

  nnoremap <buffer> o  :call AddTableCol("o")<CR>
  nnoremap <buffer> O  :call AddTableCol("O")<CR>

  nnoremap <buffer> dd :call CutTableCol()<CR>
  nnoremap <buffer> yy :call CopyTableCol()<CR>

  nnoremap <buffer> p  :call PasteTableCol("p")<CR>
  nnoremap <buffer> P  :call PasteTableCol("P")<CR>

  inoremap <buffer> <TAB> <ESC>:call IntelligentTab(0)<CR>
  nnoremap <buffer> <TAB>      :call IntelligentTab(1)<CR>

  execute 'vsplit ' . s:DBFILE
endfunc

func TableChange()
  let s:DBPOS = getpos('.')

    b! recordbuf
    call RefreshRecord()
    execute ':b ' . s:DBFILE

  call setpos('.',s:DBPOS)
endfunc

func LeaveDb()
  let s:DBPOS = getpos('.')
endfunc


"Autocommand Functions for recordbuf
func EnterRecordbuf()
  if !bufloaded(s:DBFILE)
    q
    call ToggleAutocmd()
    return
  endif

  let s:RECPOS = getpos('.')
  let s:RECBUF = getline('.')
  let s:RECLINES = line('$')
endfunc

func RecordbufMove()
  if virtcol('.') <= s:LONGEST+1
    call cursor(0,0,s:LONGEST+1)
  endif
  if virtcol('.') <= s:LONGEST+1
    execute "s/.*$/" . escape(s:DBHEAD[line('.')-1],'\/') . " -"
    call cursor(0,0,s:LONGEST+1)
  else
    call ChangeTableEntry(line('.'))
    if s:DBPOS[1] == 1
      call RefreshHeader()
    endif
  endif
endfunc

func RecordbufEnterI()
  let s:ADDCOL = "false"
  let s:RECPOS = getpos('.')
  let s:RECBUF = getline('.')
  let s:RECLINES = line('$')
endfunc

func RecordbufMoveI()
  if line('$') < s:RECLINES
    call RefreshRecord()
    call setpos('.',s:RECPOS)
  endif
  if virtcol('.') <= s:LONGEST+1 || line('.') != s:RECPOS[1]
    call setpos('.',s:RECPOS)
    execute "s/.*$/" . escape(s:RECBUF,'\/')
    call setpos('.',s:RECPOS)
  endif
endfunc

func RecordbufLeaveI()
  call ChangeTableEntry(line('.'))
  if s:DBPOS[1] == 1
    call RefreshHeader()
  endif

  if s:TABMODE == 1
    let ENTRY = GetRecEntry(line("."))
    if substitute(ENTRY, " ", "", "g") == ""
      call SetRecEntry(".", s:TABBUF)
    endif
  endif
endfunc

func LeaveRecordbuf()
  call ChangeTableEntry(line('.'))
  if s:DBPOS[1] == 1
    call RefreshHeader()
  endif
endfunc


"Functions primarily accessed by autocommand Functions
func RefreshHeader()
  let s:DBHEAD = split(getbufline(s:DBFILE,1)[0],'\s*<H>\s*', 1)

  let LEN = len(s:DBHEAD)
  let s:DBHEAD[LEN-1] = DelTrailingSpaces(s:DBHEAD[LEN-1])

  let s:LONGEST = 0
  let s:BLONGEST = 0
  for ITEM in s:DBHEAD
    let ILEN = Strlen(ITEM)
    if ILEN > s:LONGEST
      let s:LONGEST = ILEN
      let s:BLONGEST = strlen(ITEM . " ")
    endif
  endfor

  let INDEX = 0
  while INDEX < len(s:DBHEAD)
     let LEN = s:LONGEST - Strlen(s:DBHEAD[INDEX])
     while LEN > 0
       let s:DBHEAD[INDEX] = s:DBHEAD[INDEX] . " "
       let LEN = LEN - 1
     endwhile
     let INDEX = INDEX + 1
  endwhile
endfunc

func RefreshRecord()
  call ToggleAutocmd()

  let LISTE=split(getbufline(s:DBFILE, s:DBPOS[1])[0],'\s*<H>\s*',1)

  %d _
  let INDEX = 0
  while INDEX < len(s:DBHEAD)
    let ENTRY = s:DBHEAD[INDEX] . " " . get(LISTE,INDEX,"-")
    call append(line('$'),ENTRY)
    let INDEX = INDEX + 1
  endwhile
  move 0
  d _

  call ToggleAutocmd()
endfunc

func ChangeTableEntry( RECLINE )
  call ToggleAutocmd()

  let RECENTRY = DelTrailingSpaces( strpart(getline(a:RECLINE),s:BLONGEST) )
  let RECENTRYL = Strlen(RECENTRY)

  let RECPOS = getpos('.')
  let TCOL = a:RECLINE

  execute ':b ' . s:DBFILE
  let RECENTRY = RECENTRY == "" ? "-" : RECENTRY

  call InsertTableCell(RECENTRY, s:DBPOS[1], TCOL-1)
  call AdjustColWidth( TCOL )

  b! recordbuf
  call setpos(".",RECPOS)

  call ToggleAutocmd()
endfunc


"AddTableCol Functions
func AddTableCol( MODE )
  call ToggleAutocmd()
  let s:AUTO = 2

  let PREPEND = a:MODE ==# "O"

  if line('$') == line('.') && len(getline('.')) == 1
    let s:FIRSTENTRY = 1
    startinsert
  else
    let s:RECLINES = s:RECLINES + 1
    call append(line('.') - PREPEND,"")
    call cursor(line('.') + 1 - PREPEND*2, 1)
    startinsert
  endif

  let s:RECPOS = getpos('.')

  call InsertTableCol(s:RECPOS[1] - 1)

  call setpos('.',s:RECPOS)

  au CursorMovedI recordbuf call RecordbufMoveI_AddTableCol()
  au InsertLeave  recordbuf call RecordbufLeaveI_AddTableCol()
endfunc

func InsertTableCol( COL )
  let BUFFER = bufname("")
  execute "b! " . s:DBFILE

  call insert(s:DBHEAD,"-",a:COL)
  let LEN = s:LONGEST - Strlen(s:DBHEAD[a:COL])
  while LEN > 0
    let s:DBHEAD[a:COL] = s:DBHEAD[a:COL] . " "
    let LEN = LEN - 1
  endwhile

  let SEPERATOR = "<H>"
  if len(s:DBHEAD) != 1
    execute "%s/^\\(\\(.\\{-}\\(<H>\\|$\\)\\)\\{" . a:COL . "}\\)\\(.\\{-}\\)\\(<H>\\|$\\)/\\1" . SEPERATOR . "\\4\\5"
  endif

  execute "b! " . BUFFER
endfunc

func RecordbufMoveI_AddTableCol()
  if line('$') < s:RECLINES
    call RefreshRecord()
    call setpos('.',s:RECPOS)
    s/^.*$//
  endif
  if line('.') != s:RECPOS[1]
    call RefreshRecord()
    call setpos('.',s:RECPOS)
    s/^.*$//
  endif
endfunc

func RecordbufLeaveI_AddTableCol()
  let NEWCOL = line('.')
  let NEWCOLE = getline('.')
  let s:DBHEAD[NEWCOL-1] = DelTrailingSpaces(NEWCOLE)
  let s:DBHEAD[NEWCOL-1] = s:DBHEAD[NEWCOL-1] == "" ? "-" : s:DBHEAD[NEWCOL-1]

  call InsertTableCell( s:DBHEAD[NEWCOL-1], 1, NEWCOL-1 )

  call RefreshHeader()
  call RefreshRecord()
  call AdjustColWidth( NEWCOL )

  au! CursorMovedI recordbuf
  au! InsertLeave  recordbuf

  if s:FIRSTENTRY == 1
    if len(s:DBHEAD) == 2
      call remove( s:DBHEAD, 1 )
    endif
    execute "b " . s:DBFILE
    %s/^\(.\{-}\)<H>$/\1
    b recordbuf
    2d
    let s:FIRSTENTRY = 0
  endif

  call setpos('.',s:RECPOS)

  let s:AUTO = 0
  call ToggleAutocmd()
endfunc


"AddTableRow Function
func AddTableRow( MODE )
  call ToggleAutocmd()

  let PREPEND = a:MODE ==# "O"

  let HEADROW = getline(1)
  let SHEADROW = split(HEADROW,"<H>",1)

  let MAXINDEX = len(SHEADROW)
  let INDEX = 0
  while INDEX < MAXINDEX
    let SHEADROW[INDEX] = substitute(SHEADROW[INDEX], ".", " ", "g")
    let INDEX = INDEX + 1
  endwhile

  let NEWROW = join(SHEADROW,"<H>")
  call append(line('.') - PREPEND,NEWROW)
  call cursor(line('.') + 1 - PREPEND*2, 1)

  call ToggleAutocmd()
endfunc


"Functions used to cut & paste columns
func CutTableCol()
  call ToggleAutocmd()

  let COL = line(".")
  let DEC_COL = COL-1
  d

  execute ':b ' . s:DBFILE

  let s:CUTLIST = []
  call CreateColList( s:CUTLIST, COL )

  let COLPAT = "\\(.\\{-}\\(<H>\\|$\\)\\)"
  execute "%s/^\\(" . COLPAT . "\\{" . DEC_COL . "}\\)" . COLPAT . "\\(" . COLPAT . "*\\)/\\1\\6"

  if len(s:DBHEAD) == COL
    silent %s/^\(.\{-}\)<H>$/\1/
  endif

  call remove( s:DBHEAD, COL-1 )

  call ToggleAutocmd()
  b recordbuf
endfunc

func CopyTableCol()
  let COL = line(".")

  call ToggleAutocmd()
  execute ':b ' . s:DBFILE

  let s:CUTLIST = []
  call CreateColList( s:CUTLIST, COL )

  call ToggleAutocmd()
  b recordbuf
endfunc

func PasteTableCol( MODE )
  call ToggleAutocmd()

  let APPEND = a:MODE ==# "p"
  let COL = line(".") + APPEND

  execute "b! " . s:DBFILE

  call insert(s:DBHEAD, get(s:CUTLIST,0,"-"), COL-1)

  call InsertTableCol(COL-1)
  let INDEX = 1
  let MAXLINE = line("$")
  while INDEX <= MAXLINE
    call InsertTableCell( get(s:CUTLIST,INDEX-1,"-"), INDEX, COL-1 )
    let INDEX = INDEX + 1
  endwhile

  call RefreshHeader()
  call AdjustColWidth(COL)

  call ToggleAutocmd()

  b recordbuf

  call RefreshRecord()
  call cursor(COL - APPEND, 0)
endfunc


"Intelligent Tab -> see also RecordbufLeaveI()
func IntelligentTab( INRECORDVIEW )
  let FIRSTTAB = a:INRECORDVIEW
  if bufname('') != "recordbuf"
    execute bufwinnr("recordbuf") . "winc w"
    let FIRSTTAB = 1
  endif

  if s:DBPOS[1] == 1
    return
  endif

  let s:TABMODE = 1


  call ChangeTableEntry(line('.'))

  if line('.') != line('$')
    if FIRSTTAB != 1
      normal j
    endif
    let s:TABBUF = GetRecEntry(line("."))
    call SetRecEntry(".", "")
    call cursor(0,0,s:LONGEST+1)
    startinsert
  else
    execute bufnr(s:DBFILE) . "winc w"
  endif
endfunc


"Other Utilities
func CreateColList( COLLIST, COL )
  call extend( a:COLLIST, getbufline(s:DBFILE,1,"$") )
  let LONGEST = 0

  let INDEX = 0
  while INDEX < len(a:COLLIST)
    let RECORD = split(a:COLLIST[INDEX],'\s*<H>\s*')
    let a:COLLIST[INDEX] = get(RECORD,a:COL-1,"-")

    let TMPLEN = Strlen(a:COLLIST[INDEX])
    if LONGEST < TMPLEN
      let LONGEST = TMPLEN
    endif
    let INDEX += 1
  endwhile

  return LONGEST
endfunc

func InsertTableCell( ENTRY, LINE, COL )
  let BUFFER = bufname("")
  execute "b " . s:DBFILE

  let ENTRY = escape(a:ENTRY, '\/')
  execute a:LINE . "s/^\\(\\(.\\{-}<H>\\)\\{" . a:COL . "}\\).\\{-}\\(<H>\\|$\\)/\\1" . ENTRY . "\\3"

  execute "b " . BUFFER
endfunc

func AdjustColWidth( COL )
  let BUFFER = bufname("")
  execute "b " . s:DBFILE

  let COLLIST = []
  let COLWIDTH = CreateColList( COLLIST, a:COL )

  let TLINE = 1
  while TLINE <= line("$")
    while Strlen(COLLIST[TLINE-1]) < COLWIDTH
      let COLLIST[TLINE-1] = COLLIST[TLINE-1] . " "
    endwhile

    call InsertTableCell(COLLIST[TLINE-1], TLINE, a:COL-1)

    let TLINE = TLINE + 1
  endwhile

  execute "b " . BUFFER
endfunc

func Strlen( STRING )
  return strlen(substitute(a:STRING, ".", "x", "g"))
endfunc

func DelTrailingSpaces( STRING )
  return substitute(a:STRING, '^\(\S*\)\s*$', '\1', '' )
endfunc

func GetRecEntry( LINE )
  return substitute(getbufline("recordbuf",a:LINE)[0], "^.\\{" . s:LONGEST . "}\\(.*\\)$", "\\1", "")
endfunc

func SetRecEntry( LINE, ENTRY )
  let RECENTRY = escape(a:ENTRY,'\/')
  if a:LINE == "."
    execute "s/^\\(.\\{" . s:LONGEST . "}\\).*$/\\1" . RECENTRY
  else
    execute a:LINE . "s/^\\(.\\{" . s:LONGEST . "}\\).*$/\\1" . RECENTRY
  endif
endfunc
