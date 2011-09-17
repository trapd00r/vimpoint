" Version:      0.0.1_a
" Status:       Alpha
" Last change:  Wed Apr 30 08:15:30 EST 2008
" Maintainer:   Damian Conway
" License:      This file is placed in the public domain.
" Disclaimer of warranty:
"               BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS
"               NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY
"               APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE
"               COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE SOFTWARE
"               "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR
"               IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
"               WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
"               PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE
"               OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE
"               DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
"               REPAIR, OR CORRECTION. IN NO EVENT UNLESS REQUIRED BY
"               APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT
"               HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE
"               THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
"               LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL,
"               SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING
"               OUT OF THE USE OR INABILITY TO USE THE SOFTWARE
"               (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
"               RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
"               PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY
"               OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS
"               BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.


" If already loaded, we're done...
if exists("loaded_vimpoint")
  finish
endif
let loaded_vimpoint = 1

" Preserve external compatibility options, then enable full vim compatibility...
let s:save_cpo = &cpo
set cpo&vim


"=====[ SYSTEM-DEPENDENT CONFIGURATION ]=====================================
" These functions must be updated when porting to other systems
" Current set up for: MacOSX/Darwin
" (will probably work equally well on any other *NIX system)

" Can the current filesystem create symbolic links?
function! s:can_link()
    return 1
endfunction

function! s:make_link(full_path, filename)
    silent execute "silent !ln -sf " . a:full_path . " " . a:filename
    redraw!
endfunction


"=====[ CONSTANTS ]==========================================================

let g:Vimpoint_DEFAULT_ROWS = 24
let g:Vimpoint_DEFAULT_COLS = 76
let g:Vimpoint_LEFT_MARGIN  = 3

let g:Vimpoint_UNDERLINE_DELIM = 'º'
let g:Vimpoint_TITLE_DELIM     = '¹'
let g:Vimpoint_PRESENTER_DELIM = '²'
let g:Vimpoint_INFO_DELIM      = '³'

let g:Vimpoint_MIN_UNDERLINE_WIDTH = 12

let g:Vimpoint_INTERMISSION_TITLE_ROW = g:Vimpoint_DEFAULT_ROWS - 8

let g:Vimpoint_FIRSTSLIDE_TITLE_ROW     =  9
let g:Vimpoint_FIRSTSLIDE_UNDERLINE_ROW = 10
let g:Vimpoint_FIRSTSLIDE_PRESENTER_ROW = 12

let g:Vimpoint_SLIDE_NUMBER_SIZE = 3

let g:Vimpoint_EXAMPLE_SEARCH_PATH = '../,../example/,../examples/,../demo/,../demos/'


let s:ESCAPED_CHAR   = '\\{\|\\}\|\\\*\|\\\\'
let s:SINGLE_CONTENT    = '\%(' . s:ESCAPED_CHAR . '\|.\)'

let s:CODEEMPH_START_PAT = '{{\*\*\|\*\*{{'
let s:CODEEMPH_END_PAT   = '}}\*\*\|\*\*}}'
let s:CODEEMPH_ONE_PAT   =
\   '{{\*\*'.s:SINGLE_CONTENT.'\*\*}}\|\*\*{{'.s:SINGLE_CONTENT.'}}\*\*'

let s:EMPH_START_PAT = '\*\*'
let s:EMPH_END_PAT   = '\*\*'
let s:EMPH_ONE_PAT   = '\*\*'.s:SINGLE_CONTENT.'\*\*'

let s:CODE_START_PAT = '{{'
let s:CODE_END_PAT   = '}}'
let s:CODE_ONE_PAT   = '{{'.s:SINGLE_CONTENT.'}}'
let s:CODE_DELIM     = s:CODE_START_PAT .'\|'. s:CODE_END_PAT

let s:FORMATTER_PAT  = '\(.\{-}\)\(' . join([
\                                         s:ESCAPED_CHAR,
\                                         s:CODEEMPH_ONE_PAT,
\                                         s:CODEEMPH_START_PAT,
\                                         s:CODEEMPH_END_PAT,
\                                         s:EMPH_ONE_PAT,
\                                         s:EMPH_START_PAT,
\                                         s:EMPH_END_PAT,
\                                         s:CODE_ONE_PAT,
\                                         s:CODE_START_PAT,
\                                         s:CODE_END_PAT,
\                                  ], '\|')
\                    . '\)\(.*\)'

let s:SINGLE_CHAR
\   = '\*\*{{.}}\*\*\|\*\*.\*\*\|{{.}}\|'
\   . '.\*\*{{\|.\*\*}}\|.\*\*\|.{{\*\*\|.}}\*\*\|.{{\|.}}\|'
\   . '\*\*{{.\|\*\*}}.\|\*\*.\|{{\*\*.\|}}\*\*.\|{{.\|}}.\|'
\   . s:ESCAPED_CHAR
\   . '\|.'

"============================================================================

" Set-up Vimpoint files when they're displayed...
augroup Vimpoint
au!
    au BufEnter  *.vpt   call VimpointSpecificationSetup()
    au BufLeave  *.vpt   call VimpointSpecificationCleanup()

    au BufEnter  *.vps   call VimpointSlideSetup('vps')
    au BufEnter  *.vpa   call VimpointSlideSetup('vpa')
    au BufEnter  *.vpf   call VimpointSlideSetup('vpf')
    au BufEnter  *.vpi   call VimpointSlideSetup('vpi')
    au BufEnter  *.vpe   call VimpointSlideSetup('vpe')

    au BufLeave  *.vps   call VimpointSlideCleanup('vps')
    au BufLeave  *.vpa   call VimpointSlideCleanup('vpa')
    au BufLeave  *.vpf   call VimpointSlideCleanup('vpf')
    au BufLeave  *.vpi   call VimpointSlideCleanup('vpi')
    au BufLeave  *.vpe   call VimpointSlideCleanup('vpe')

    au CursorHold *.vpa     call VimpointTimerUpdate()

augroup END

" Decode b:vpt.formatting data into syntax regexes...
function! s:build_page_specific_syntax (category, formatting)
    let syntax_pat = {}

    " Invert and combine: line --> start/end/one --> group -->  pos
    "         to produce: group --> start/end/one --> line+pos
    for formatline in a:formatting
        let line = '\%' . formatline.row . 'l'
        for group in keys(formatline.start)
            if !has_key(syntax_pat, group)
                let syntax_pat[group] = { 'start':[], 'end':[], 'one':[] }
            endif
            for startpos in formatline.start[group]
                let syntax_pat[group].start += [ line . '\%' . startpos . 'c.' ]
            endfor
            for endpos in formatline.end[group]
                let syntax_pat[group].end += [ line . '\%' . endpos . 'c.' ]
            endfor
            for onepos in formatline.one[group]
                let syntax_pat[group].one += [ line . '\%' . onepos . 'c.' ]
            endfor
        endfor
    endfor

    let syntaxes = []

    " Translate to std Vim 'syntax' commands...
    for group in keys(syntax_pat)
        let groupname = a:category . group
        let startpos = join(syntax_pat[group].start, '\|')
        let endpos   = join(syntax_pat[group].end,   '\|')
        let onepos   = join(syntax_pat[group].one,   '\|')
        if strlen(startpos) && strlen(endpos)
            let syntaxes += [
            \   'syntax region ' . groupname
            \ . ' start=/' . startpos . '/'
            \ . '   end=/' . endpos . '/'
            \ . ( groupname == 'CodeEmph' ? 'containedin=ALL' : "")
            \ ]
        endif
        if strlen(onepos)
            let syntaxes += [
            \   'syntax match ' . groupname . 'One'
            \ . ' /' . onepos . '/'
            \ . ( groupname == 'CodeEmph' ? 'containedin=ALL' : "")
            \ ]
        endif
    endfor

    return syntaxes

endfunction

function! VimpointSpecificationSetup ()
    " Turn on syntax highlighting...
    syntax enable
    set syntax=vimptvpt

    " Set up colon commands to generate presentations & handouts...
    command!  -buffer -bar  Compile  :call s:compile()
    command!  -buffer -bar  Handout  :call s:handout()
    command!  -buffer -bar -range=0 -nargs=?
    \                       Run      :call s:run(<count>, '<args>')

    " Map normal-mode keys to generate presentations & handouts...
    nnoremap  <buffer>      <TAB>    :Run 1<CR>
    nnoremap  <buffer>      <S-TAB>  :Resume<CR>

    " Useful commands to help with formatting...
    nnoremap  <buffer>      *        diWi****<LEFT><ESC>P
    nnoremap  <buffer>      {        diWi{{}}<LEFT><ESC>P

    " Warn of chars that will be off-screen to the right in the slides...
    let b:VimpointRestoreMatches = [ matcharg(1), matcharg(2) ]
    call map(b:VimpointRestoreMatches,
    \        'v:val[0]==""?["none",""]:[v:val[0],"/".v:val[1]."/"]')
    execute printf('2match  VPTEdgeScreen   /^\(%s\)\{%d}\zs.\+/',
    \          s:SINGLE_CHAR, winwidth(0)-6)
    execute printf('1match  VPTOffScreen   /^\(%s\)\{%d}\zs.\+/',
    \          s:SINGLE_CHAR, winwidth(0)-3)

    " Set up folding support...
    let b:VimpointRestoreFolds
    \   = [ &foldmethod, &foldexpr, &foldlevel, &foldtext ]
    set foldmethod=expr
    set foldexpr=VimpointGetFoldLevel(v:lnum)
    set foldlevel=2
    set foldtext=VimpointGetFoldText()

    " Remap fold commands to adjust highlights according to foldlevel...
    for cmd in  split('A C M N O R X a c i m n o r v x')
        execute 'nnoremap <buffer> <silent> z' . cmd
              \ ' z' . cmd . ':call VimpointSetFoldHighlight()<CR>'
    endfor
endfunction

function! VimpointSetFoldHighlight ()
    if &foldlevel == 1
        highlight! link Folded VPTFoldedHeadings
    elseif &foldlevel == 0
        highlight! link Folded VPTFoldedSections
    else
        highlight! link Folded NONE
    endif
endfunction

function! VimpointGetFoldText()
    " Build fold text...
    let linecount = string(v:foldend - v:foldstart + 1)
    let line = substitute(getline(v:foldstart),'\s\+$',"","")
    let midgap = winwidth(0) - strlen(line) - strlen(linecount) - 6
    return printf("%s%*s%s lines", line, midgap, "", linecount)
endfunction

function! VimpointGetFoldLevel(lineno)
    let prevline = getline(a:lineno-1)
    let line     = getline(a:lineno)
    let nextline = getline(a:lineno+1)

    " A few global directives are not folded...
    if line =~ s:METAINFO_PAT || line =~ s:INTERMISSION_PAT
        return 0

    " Before a section header, empty lines aren't folded...
    elseif line =~ '^\s*$' && nextline =~ s:SECTION_PAT
        return 0

    " Section headers are folded to the first level...
    elseif line =~ s:SECTION_PAT
        return 1

    " Before a header, empty lines are folded one level less...
    elseif line =~ '^\s*$' && nextline =~ s:HEADER_PAT
        return 1

    " Everything else is folded to the second level...
    else
        return 2

    endif
endfunction

function! VimpointSpecificationCleanup ()
    for n in range(len(b:VimpointRestoreMatches))
        let [group, pattern] = b:VimpointRestoreMatches[n]
        execute printf("%dmatch %s %s", n+1, group, pattern)
    endfor

    " Restore folding behaviour...
    let [ &foldmethod, &foldexpr, &foldlevel, &foldtext ]
    \   = b:VimpointRestoreFolds
    highlight! link Folded NONE

    " Unmap fold commands...
    for cmd in  split('A C M N O R X a c i m n o r v x')
        try
            execute 'nunmap z' . cmd
        catch
            " Ignore non-existent mappings
        endtry
    endfor
endfunction


function! VimpointSlideSetup (filetype)
    " Activate syntax highlighting...
    syntax enable
    execute 'set syntax=vimpt' . a:filetype

    " Notify general colourscheme hint...
    let b:prev_background = &background
    let &background = a:filetype =~ 'vp[afi]' ? 'light' : 'dark'

    " Minimize statusline and tabline...
    let b:vimpoint_restore_ruler = &ruler
    setlocal noruler
    setlocal showtabline=0

    " No window title to distract the audience...
    let &title = 1
    let &titlestring = " "

    " Load metadata and execute any 'enter_slide_action'...
    let b:vpt = s:load_metadata_for(expand('%:p'))
    execute get(b:vpt, 'enter_slide_action', '')

    " Suspend timer in intermission slides
    if a:filetype == 'vpi'
        let g:SuspendedTimer = localtime()
        call VimpointIntermissionTimer(b:vpt.duration)
    endif

    " Slide-specific setup or source jumping only for non-example slides...
    if a:filetype != 'vpe'
        " Shorten updatetime
        let b:VimpointSavedUpdateTime = &updatetime
        let &updatetime = 5

        if exists('b:vpt') && has_key(b:vpt,'formatting')
            for syntax_command in b:vpt.formatting
                execute syntax_command
            endfor
        endif
    endif

    " Command to return to specification of presentation...
    command! -buffer  Specification      :call s:edit_specification()

    " Targeted and linked navigation within presentation...
    if expand('%:t') =~ '^TMP'
        nnoremap <buffer><silent> <TAB>   :quit!<CR>
        nnoremap <buffer><silent> <S-TAB> :quit!<CR>
        nnoremap <buffer><silent> <DOWN>  :quit!<CR>
        nnoremap <buffer><silent> <UP>    :quit!<CR>
        nnoremap <buffer><silent> <LEFT>  :quit!<CR>
        nnoremap <buffer><silent> <RIGHT> :quit!<CR>
        nnoremap <buffer><silent> <SPACE> :quit!<CR>
        nunmap                    ZZ
    else
        nnoremap <buffer><silent>  ZZ  :call VimpointConfirmQuit()<CR>
        nnoremap <buffer><silent>  <TAB>
        \                  :call VimpointFindTarget('next')<CR>
        nnoremap <buffer><silent>  <S-TAB>
        \                  :call VimpointFindTarget('all')<CR>
        nnoremap <buffer><silent>  <SPACE>
        \                  :call VimpointNextFile(1,'advance')<CR><C-L>
        nnoremap <buffer><silent>  <DOWN>
        \                  :call VimpointNextFile(1,'advance')<CR><C-L>
        nnoremap <buffer><silent>  <UP>
        \                  :call VimpointNextFile(-1,'advance')<CR><C-L>
        " nnoremap <buffer><silent>  b
        " \                  :call VimpointNextFile(-1,'advance')<CR><C-L>
        " nnoremap <buffer><silent>  B
        " \                  :call VimpointNextFile(-1,'advance')<CR><C-L>
        if expand('%:t') !~ '.vpe$'
            nnoremap <buffer><silent>  <RIGHT>
            \                  :call VimpointNextFile(1,'slide')<CR><C-L>
            nnoremap <buffer><silent>  <LEFT>
            \                  :call VimpointNextFile(-1,'slide')<CR><C-L>
        endif

        " Unscheduled intermission...
        command!  -buffer -bar -range=0 -nargs=?
        \   Intermission     :call s:intermit(<count>, '<args>')
        nnoremap <buffer><silent>  <C-P>    :Intermission 1<CR>
    endif

    " In-presentation editing facilities...
    nnoremap <buffer><silent>  <C-E>    :call VimpointEditSlideCopy()<CR><CR>
    nnoremap <buffer><silent>  <C-T>    :call VimpointEditScratchpad()<CR><CR>

    " Map keys for any selectors...
    let selector_links = get(b:vpt, 'selector_links', {})
    for key in keys(selector_links)
        execute 'nnoremap <buffer> ' . key . ' :call VimpointSelector("' . key . '")<CR>'
    endfor

    " Fit to screen...
    if a:filetype =~ 'vp[asfi]'
        call s:trim_right_edge()
    endif

endfunction

function! VimpointSelector (key)
    " Work out where we're going...
    let link = get(b:vpt.selector_links, a:key, "")
    if link == ""
        return
    endif

    " Work out which selection was made, and highlight it...
    let text = get(b:vpt.selector_texts, a:key, "")
    call cursor(1,1)
    highlight VimpointSelector ctermfg=white    ctermbg=blue  cterm=bold
    execute '2match VimpointSelector /\V' . escape(text,'\\') . '/'
    redraw

    " Get confirmation...
    echo ""
    let input = nr2char(getchar())

    " Clear the selection...
    2match none
    redraw

    " If they hit <ENTER>, jump to that link...
    if input == "\<CR>"
        " If the link is to an external presentation, run it...
        if link =~ '\.vpp$'
            if isdirectory(link)
                execute 'tab next ' . link . '/*.vp[safie]'
            else
                echo "Couldn't find external link: " link
                sleep 2
            endif

        " Otherwise, find the internal target and jump there...
        else 
            " Assemble potential targets...
            let currdir = expand('%:p:h')
            let file_for = get(s:load_metadata_for(glob(currdir . '/*.vpf')), 'all_targets', {})

            " Jump to the target...
            let target = get(file_for, link, "")
            if target != ""
                execute "call s:goto_slide_file(glob('" . currdir . '/' . target . "*'))"
            else
                echo "Couldn't find internal link: " link
                sleep 2
            endif
        endif

    " Otherwise if they selected another link, highlight that one...
    elseif exists('b:vpt.selector_links["' . input . '"]')
        call VimpointSelector(input)
    endif

endfunction

function! VimpointConfirmQuit ()
    echo '???'
    let input = nr2char(getchar())
    if input =~ '[yYZ]'
        q!
    endif
endfunction

function s:trim_right_edge ()
    silent execute '0,$-1s/\%>' . (g:Vimpoint_DEFAULT_COLS-1) . 'v.*//'
    nohlsearch
    1
endfunction

function! VimpointSlideCleanup (filetype)
    " Restore ruler setting...
    let &ruler = b:vimpoint_restore_ruler

    " Restore previous colourscheme hint...
    let &background = b:prev_background

    " Prep timer if on title slide...
    if a:filetype == 'vpf' || !exists('g:VimpointTimerStart')
        let g:VimpointTimerStart = localtime()
    endif

    " Adjust presentation timer so as not to count intermissions...
    if a:filetype == 'vpi'
        let intermission_time = localtime() - g:SuspendedTimer
        let g:VimpointTimerStart += intermission_time
        if expand('%:t') =~ '^TMP'
            call delete(expand('%:p'))
        endif
    endif

endfunction


" Create and display an elapsed time indicator...

let s:unit_for = { 's':1, 'm':60, 'h':3600, 'd':86400 }

function! VimpointTimerUpdate ()
    " Restore normal updating...
    let &updatetime = b:VimpointSavedUpdateTime

    " Find the duration...
    if exists('g:VimpointRunDuration')
        let duration = g:VimpointRunDuration
    else
        let duration_spec =
        \   matchlist(get(get(b:vpt,'pres_duration',[]),0,'0'), '\(\d\+\)\s*\(\S\?\)' )

        if !len(duration_spec)
            return
        endif

        " Translate duration to seconds (if no unit, assume "minutes")...
        let unit = get(s:unit_for, tolower(duration_spec[2]), s:unit_for.m)
        let duration = str2nr(duration_spec[1]) * unit

        if !duration
            return
        endif
    endif

    " Repeat update until any other key pressed...
    while !getchar(1)
        let max_width = winwidth(0)-1

        " Determine physical progress through slide files...
        let slidenum = str2nr(substitute(expand("%:t"),'\D.*',"",""))
        let slidecount = len(split(glob(expand("%:p:h").'/[0-9]*'),"\n"))
        let slidepos = min([max_width, slidenum * max_width / slidecount])

        " Determine temporal progress through specified duration...
        let elapsed = localtime() - g:VimpointTimerStart
        let elapsedpos = min([max_width, elapsed * max_width / duration])

        " Generate a graphic illustrating the two...
        let indicator = printf("%-*s", max_width, repeat('_', slidepos))
        let indicator = substitute(indicator, '\%'.elapsedpos.'c.', '.', "")

        " Display the graphic (urgent in the last two minutes)...
        if duration-elapsed < 120
            echohl VPATimerDisplay
        else
            echohl VPATimerDisplayEnd
        endif

        echo   indicator
        echohl None
    endwhile
endfunction

"============================================================================

" Syntax highlighter for .vpa files
" (Expects a call to VPAHi on the last line of the file)

function! VPAHiCmd (name, data)
    let cmds = []
    while len(a:data)
        let [line, start_col, length] = remove(a:data,0,2)
        let cmds += ['\%' . line . 'l\%' . start_col . 'c' . repeat('.', length)]
    endwhile
    return 'syntax match ' . a:name . ' /' . join(cmds, '\|') . '/'
endfunction

function! VPAHi (emph, code)
    execute VPAHiCmd('VPAEmph', a:emph)
    execute VPAHiCmd('VPACode', a:code)
endfunction

"============================================================================


"=====[ HANDLE METADATA ]====================================================

function! s:load_metadata_for (filename)
    " Locate the metafile...
    let metafile  = fnamemodify(a:filename, ':h') . '/METADATA'

    " Extract the data...
    let g:VPT_metadata = {}
    execute 'source ' . metafile

    " Return the data for the specified file...
    return get(g:VPT_metadata, a:filename, {})
endfunction

function! s:save_metadata_for (filename, metadata)
    " Locate the metafile...
    let metafile  = fnamemodify(a:filename, ':h') . '/METADATA'

    " Read in the existing metadata...
    try
        let contents = readfile(metafile)
    catch
        let contents = []
    endtry

    " Append the new metadata...
    call writefile(contents + ["let g:VPT_metadata['" . a:filename . "'] = " . string(a:metadata)], metafile)
endfunction


"=====[ CREATE SLIDES OF VARIOUS TYPES ]=====================================

function! s:centre_text (text, ...)
    let width = a:0 ? a:1 : g:Vimpoint_DEFAULT_COLS
    let indent = (width - strlen(a:text))/2
    return printf("%-*s", width, repeat(' ',indent) . a:text)
endfunction

function! s:create_line (length)
    return g:Vimpoint_UNDERLINE_DELIM . repeat(" ",a:length) .  g:Vimpoint_UNDERLINE_DELIM
endfunction

function! s:create_title (title)
    return g:Vimpoint_TITLE_DELIM . a:title .  g:Vimpoint_TITLE_DELIM
endfunction

function! s:create_presenter (presenter)
    return g:Vimpoint_PRESENTER_DELIM . a:presenter .  g:Vimpoint_PRESENTER_DELIM
endfunction

function! s:create_info (info)
    return g:Vimpoint_INFO_DELIM . a:info .  g:Vimpoint_INFO_DELIM
endfunction

function! s:create_centred_on_title (title_line, text)
    let title_start  = match(a:title_line, '\S')
    let title_end    = match(a:title_line, '\s*$')
    let title_centre = (title_start + title_end)/2

    let indent = title_centre - strlen(a:text)/2
    return printf("%-*s", g:Vimpoint_DEFAULT_COLS, repeat(' ',indent) . a:text)
endfunction


" Create a named .vpf file for a given presentation...
function! s:create_vpf_file (slidenum, pres, slide, currdir) abort
    " No title slide for presentations with no metainfo...
    if !( len(a:pres['title']) || len(a:pres['presenter']) || len(a:pres['info']))
        return
    endif

    let a:slide.context.formatting = []

    let a:slide.context.slide_number
    \   = printf('%0*d.', g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)

    " Background of spaces...
    let lines = repeat( [repeat(' ',g:Vimpoint_DEFAULT_COLS)],
                      \ g:Vimpoint_DEFAULT_ROWS)

    " Title line(s)...
    let row = g:Vimpoint_FIRSTSLIDE_TITLE_ROW
    for title in reverse(copy(a:pres.title))
        let [lines[row], formatting]
        \   = s:deformat(s:centre_text(s:create_title(s:trim_text(title))), row,
        \                {'centred':1, 'category':'Title'} )
        let row -= 1
        let a:slide.context.formatting += [formatting]
    endfor

    " Underline between title and identity...
    let lines[g:Vimpoint_FIRSTSLIDE_UNDERLINE_ROW]
        \ = s:centre_text(s:create_line(g:Vimpoint_DEFAULT_COLS-6))

    " Presenter name line(s)...
    let row = g:Vimpoint_FIRSTSLIDE_PRESENTER_ROW
    let presenter_lines = a:pres.presenter
    for presenter in presenter_lines
        let [lines[row], formatting]
        \   = s:deformat(s:centre_text(s:create_presenter(s:trim_text(presenter))), row,
        \                {'centred':1, 'category':'Name'} )
        let row += 1
        let a:slide.context.formatting += [formatting]
    endfor

    " Separate info from presenter if more than one presenter or info line...
    let info_lines    = a:pres.info
    if len(presenter_lines) > 1 || len(info_lines) > 1
        let row += 1
    endif
    for info in info_lines
        let [lines[row], formatting]
        \   = s:deformat(s:centre_text(s:create_info(s:trim_text(info))), row,
        \                {'centred':1, 'category':'Info'} )
        let row += 1
        let a:slide.context.formatting += [formatting]
    endfor

    " Convert formatting to std 'syntax' commands...
    let a:slide.context.formatting
    \   = s:build_page_specific_syntax('VPF', a:slide.context.formatting)

    " Save targeting info...
    let a:slide.context.all_targets = s:all_targets

    " Create filename...
    let filename = printf('%0*d._TITLE.vpf',
                             \ g:Vimpoint_SLIDE_NUMBER_SIZE,
                              \ a:slidenum)

    " Create the file and save its metadata...
    call writefile(lines, filename)
    call s:save_metadata_for(a:currdir . '/' . filename, a:slide.context)

endfunction


function! s:trim_text (text)
    return substitute(a:text, '^\s*\|\s*$', "", 'g')
endfunction

" Create a named .vpi file for a given presentation...
function! s:create_vpi_file (slidenum, pres, slide, currdir) abort
    " Remember where we parked...
    let a:slide.context.slide_number = a:slidenum =~ '\d'
    \   ? printf("%0*s", g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)
    \   : a:slidenum

    " Background of spaces...
    let lines = repeat( [repeat(' ',g:Vimpoint_DEFAULT_COLS)],
            \           g:Vimpoint_DEFAULT_ROWS)


    " Save specified duration of the intermission (if any)
    let a:slide.context.duration = a:slide.duration

    " Presentation title line(s)...
    let title_lines = copy(a:pres.title)
    call map(title_lines,
    \        "s:deformat(s:trim_text(v:val), 0, {'centred':1,'category':'Title'})[0]"
    \)
    let title_len   = max(map(copy(title_lines), 'strlen(v:val)'))
    let title_start = max([
        \ g:Vimpoint_MIN_UNDERLINE_WIDTH,
        \ g:Vimpoint_DEFAULT_COLS - g:Vimpoint_MIN_UNDERLINE_WIDTH - title_len
    \])

    let left_line  = repeat(" ", title_start)
    let right_line = repeat(" ", g:Vimpoint_DEFAULT_COLS - title_len - title_start)

    let title_row = g:Vimpoint_INTERMISSION_TITLE_ROW
    for title in reverse(title_lines)
        let lines[title_row] = left_line
                           \ . s:centre_text(title, title_len)
                           \ . right_line
        let title_row -= 1
    endfor

    " Presenter name line...
    let name_row = g:Vimpoint_INTERMISSION_TITLE_ROW+1
    let name_lines = copy(a:pres.presenter)
    call map(name_lines,
    \        "s:deformat(s:trim_text(v:val), 0, {'centred':1,'category':'Name'})[0]"
    \)
    for name in name_lines
        let lines[name_row] = s:create_centred_on_title(
                            \   lines[g:Vimpoint_INTERMISSION_TITLE_ROW],
                            \   name
                            \ )
        let name_row += 1
    endfor

    " Create the file...

    let fileno = a:slidenum =~ '\d'
    \   ? printf("%0*s", g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)
    \   : a:slidenum

    let filename = printf("%s._INTERMISSION.vpi", fileno)

    call writefile(lines, filename)
    call s:save_metadata_for(a:currdir . '/' . filename, a:slide.context)

    return filename
endfunction

function! s:create_vpe_file (slidenum, pres, slide, currdir)
    if empty(a:slide.content)
        return
    endif

    let a:slide.context.slide_number
    \   = printf('%0*d.', g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)

    let lines = a:slide.content

    " Left-justify according to first line...
    let leader_len = matchend(lines[0], '^\s\+')
    call map(lines, 'strpart(v:val,'.leader_len.')' )

    " Generate filename and write the file...
    let filename = printf('%0*d._EXAMPLE.vpe',
                         \   g:Vimpoint_SLIDE_NUMBER_SIZE,
                         \    a:slidenum)
    call writefile(lines, filename)
    call s:save_metadata_for(a:currdir . '/' . filename, a:slide.context)
endfunction

function! s:create_vpd_file (slidenum, pres, slide, currdir)

    " Assume the worst...
    let lines = [
    \ '***',
    \ '***  Could not find a readable file for: ',
    \ '*** ',
    \ '***     =example  '. a:slide.source,
    \ '***',
    \ '***  requested at ' . a:slide.context.file
    \                      . ', line ' .  a:slide.context.line,
    \ '***',
    \]

    " Locate specified source file...
    let paths =
    \   split(glob( a:slide.source ), "\n")
    \ + split(glob( '../' . a:slide.source ), "\n")
    \ + split(globpath( g:Vimpoint_EXAMPLE_SEARCH_PATH, '**/' . a:slide.source ), "\n")

    let full_path = ""

    " Try to retrieve contents...
    let found = 0
    for path in paths
        try
            if get(a:slide, 'is_active', 0)
                let full_path = path
            else
                let lines = readfile(path)
            endif
            break
        catch
            " Ignore failures
        endtry
    endfor

    " Generate filename and write the file...
    let filename = printf('%0*d._%s.vpe',
                         \   g:Vimpoint_SLIDE_NUMBER_SIZE,
                         \    a:slidenum,
                         \        substitute(a:slide.source, '.*\/', "", ""))

    " If it's a link and links are possible, link it, otherwise write it...
    if get(a:slide, 'is_active', 0) && s:can_link()
        if full_path == ""
            let full_path = '../' . a:slide.source
            call writefile(lines, full_path)
        endif
        call s:make_link(full_path, filename)
    else
        call writefile(lines, filename)
    endif

    let a:slide.context.slide_number
    \   = printf('%0*d.', g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)

    call s:save_metadata_for(a:currdir . '/' . filename, a:slide.context)

endfunction

function! s:create_vpa_file (slidenum, pres, slide, currdir)
    " Ignore empty advances immediately after a section slide
    " (indicated by .first of -1)...
    if a:slide.first == -1 && len(a:slide.content) == 0
        return
    endif

    " Background of spaces...
    let lines = repeat( [repeat(' ',g:Vimpoint_DEFAULT_COLS*2)],
                      \ g:Vimpoint_DEFAULT_ROWS)

    " Title line(s)...
    let row = 1
    let a:slide.context.formatting = []
    for title in a:slide.title
        let [lines[row], formatting]
        \   = s:deformat(s:centre_text(title), row,
        \                {'centred':1, 'category':'Title'} )
        let row += 1
        let a:slide.context.formatting += [formatting]
    endfor

    " Leave space for separator line and trailing space...
    let row += 2

    " Content...
    let in_bullet = 0
    for content in a:slide.content
        let in_bullet =  content =~ '^\S'  ?  1
        \             :  content !~ '\S'   ?  0
        \             :                       in_bullet
        let in_codeblock = !in_bullet && content =~ '^\s'

        let [ deformatted, formatting ]
            \ = s:deformat(content, row,
            \              {'codeblock': in_codeblock,
            \               'offset':    g:Vimpoint_LEFT_MARGIN}
            \)

        let lines[row] = printf("%-*s", g:Vimpoint_DEFAULT_COLS, deformatted)
        let row += 1
        let a:slide.context.formatting += [formatting]
    endfor

    " Convert formatting to std 'syntax' commands...
    let a:slide.context.formatting
    \   = s:build_page_specific_syntax('VPA', a:slide.context.formatting)

    " Complete the file's metadata...
    let a:slide.context.pres_duration = get(a:pres,'duration',[])
    let a:slide.context.slide_number
    \   = printf('%0*d.', g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)

    " Generate filename and write the file and its metadata...
    let desc = substitute(a:slide.title[0], '[^[:alnum:]]\+', '_', 'g')
    let desc = substitute(desc, '^_\+', "", 'g')
    let filename = printf('%0*d.%s.vpa', g:Vimpoint_SLIDE_NUMBER_SIZE,
                         \               a:slidenum,
                         \               (a:slide.first ? '_' . desc : desc))

    call writefile(lines, filename)
    call s:save_metadata_for(a:currdir . '/' . filename, a:slide.context)
endfunction


function! s:create_vps_file (slidenum, pres, slide, currdir)
    " Background of spaces...
    let lines = repeat( [repeat(' ',g:Vimpoint_DEFAULT_COLS)],
                      \ g:Vimpoint_DEFAULT_ROWS)

    " Title line(s)...
    let row = 1
    let a:slide.context.formatting = []
    for title in a:slide.title
        let [lines[row], formatting]
        \   = s:deformat(s:centre_text(title), row,
        \                {'centred':1, 'category':'Title'} )
        let row += 1
        let a:slide.context.formatting += [formatting]
    endfor

    " Convert formatting to std 'syntax' commands...
    let a:slide.context.formatting
    \   = s:build_page_specific_syntax('VPS', a:slide.context.formatting)

    " Complete the slide's metadata...
    let a:slide.context.pres_duration = get(a:pres,'duration',[])
    let a:slide.context.slide_number
    \   = printf('%0*d.', g:Vimpoint_SLIDE_NUMBER_SIZE, a:slidenum)

    " Generate filename and write the file and its metadata...
    let desc = substitute(a:slide.title[0], '[^[:alnum:]]\+', '_', 'g')
    let desc = substitute(desc, '^_\+', "", 'g')
    let filename = printf('%0*d.%s.vps', g:Vimpoint_SLIDE_NUMBER_SIZE,
                         \               a:slidenum,
                         \               (a:slide.first ? '_' . desc : desc))

    call writefile(lines, filename)
    call s:save_metadata_for(a:currdir . '/' . filename, a:slide.context)
endfunction


"=====[ CREATE HTML REPRESENTATION OF VARIOUS SLIDE TYPES ]===================

let s:BR = '<br/>'

" Create HTML for a vpf slide...
function! s:create_vpf_html (slidenum, pres, slide) abort
    let html = []

    " Title line(s)...
    let html += ['<p  class="VimpointPresTitle">']
    for title in a:pres.title
        let html += [ s:format_html(title, {}) . s:BR ]
    endfor
    let html += ['</p>']

    " Presenter name line(s)...
    let html += ['<p class="VimpointPresName">']
    for presenter in a:pres.presenter
        let html += [ s:format_html(presenter, {}) . s:BR ]
    endfor
    let html += ['</p>']

    let html += ['<p class="VimpointPresInfo">']
    for info in a:pres.info
        let html += [ s:format_html(info, {}) . s:BR ]
    endfor
    let html += ['</p>']

    return html
endfunction

" Create no HTML for a vpi slide...
function! s:create_vpi_html (slidenum, pres, slide) abort
    return []
endfunction

" Create HTML for a vpe or vpd slide...
function! s:create_vpe_html (slidenum, pres, slide)
    if empty(a:slide.content)
        return []
    endif

    let lines = a:slide.content
    let html = []

    " Left-justify according to first line...
    let leader_len = matchend(lines[0], '^\s\+')
    call map(lines, 'strpart(v:val,'.leader_len.')' )

    " Format caption (if any)...
    if exists('a:slide.title')
        let html +=  [
        \   '<p  class="VimpointExampleCaption">',
        \   a:slide.title[0],
        \   '</p>'
        \]
    endif

    " Format content...
    let html += [ '<p class="VimpointExample">' ]
    for line in lines
        let html += [ s:format_html(line, { 'codeblock': 1}) ]
    endfor
    let html += [ '</p>' ]

    return html
endfunction

function! s:create_vpd_html (slidenum, pres, slide)
    " Locate specified source file...
    let paths =
    \   split(glob( '../' . a:slide.source ), "\n")
    \ + split(globpath( g:Vimpoint_EXAMPLE_SEARCH_PATH, '**/' . a:slide.source ), "\n")

    " Try to retrieve contents...
    let found = 0
    let lines = []
    for path in paths
        try
            let lines = readfile(path)
            break
        catch
            " Ignore failures
        endtry
    endfor

    if !len(lines)
        return []
    endif

    " Format content...
    let html = [
    \   '<p  class="VimpointExampleCaption">',
    \   a:slide.source,
    \   '</p>',
    \   '<p class="VimpointExample">',
    \]

    for line in lines
        let html += [ s:format_html(line, { 'literal': 1}) ]
    endfor
    let html += [ '</p>' ]

    return html
endfunction

" Create HTML for a vpa slide...
function! s:create_vpa_html (slidenum, pres, slide)
    let html = []

    " Title line(s)...
    if a:pres.prev_title != a:slide.title
        let html += [ '<p  class="VimpointSlideTitle">' ]
        for title in a:slide.title
            let html += [ s:format_html(title, {}) ]
        endfor
        let html += [ '</p>' ]
    endif

    " Content...
    let [in_bullet, in_codeblock] = [0,0]
    for content in a:slide.content
        if content =~ '^\S'
            let content = substitute(content, '^\S', "", "")
            if in_codeblock
                let html += [ '</p>' ]
            endif
            let [in_bullet, in_codeblock] = [1,0]
            let html += [ '<li class="VimpointSlideBullet">' ]
        elseif content !~ '\S'
            let html += in_bullet ? [ "</li>" ] : []
            let in_bullet = 0
        endif

        if !in_codeblock && !in_bullet && content =~ '^\s'
            let in_codeblock = 1
            let html += [ '<p class="VimpointSlideCodeBlock">' ]
        endif

        let html += [
        \   in_codeblock ? s:format_html(content, {'codeblock': 1})
        \                : s:format_html(content, {})
        \]
    endfor

    let html +=
    \   in_codeblock ? [ '</p>' ]
    \ : in_bullet    ? [ '</li>'  ]
    \ :                []

    return html
endfunction


" Create HTML for a vpa slide...
function! s:create_vps_html (slidenum, pres, slide)
    let html = []

    " Title line(s)...
    if a:pres.prev_title != a:slide.title
        let html += [ '<p  class="VimpointSectionTitle">' ]
        for title in a:slide.title
            let html += [ s:format_html(title, {}) ]
        endfor
        let html += [ '</p>' ]
    endif

    return html
endfunction


"=====[ Extract syntax match formatting for a slide ]==================

function! s:formatpat (row, col, len)
    return '\%' .(row+1). 'l\%' .(col+1). 'c.\{' .len. '}'
endfunction


function! s:deformat (text, row, opt)
    let is_centred      = get(a:opt, 'centred',   0 )
    let is_codeblock    = get(a:opt, 'codeblock', 0 )
    let category        = get(a:opt, 'category',  "")
    let external_offset = get(a:opt, 'offset',    0 )

    " Track where formatting starts and ends...
    let categories = {
    \   category.'Code':[],
    \   category.'Emph':[],
    \   category.'CodeEmph':[],
    \   category.'CodeblockEmph':[],
    \}
    let start = deepcopy(categories)
    let end   = deepcopy(categories)
    let one   = deepcopy(categories)

    " Codeblocks use different highlight names...
    let code     = category .                                   'Code'
    let emph     = category . (is_codeblock ? 'CodeblockEmph' : 'Emph')
    let codeemph = category . (is_codeblock ? 'CodeblockEmph' : 'CodeEmph')

    " Track locations and state within text
    let [offset, in_emph, in_code] = [0, 0,0]

    " Search through the line...
    let still_to_search = a:text
    let deformatted_text = ""
    while 1
        let startpos = strlen(deformatted_text)
        let matched = matchlist(still_to_search, s:FORMATTER_PAT)
        if empty(matched)
            let deformatted_text .= still_to_search
            break
        endif

        " What did we find?
        let [prefix, delim, still_to_search] = matched[1:3]

        " Apparent code delims inside a codeblock are really literals...
        if is_codeblock && delim =~ s:CODE_DELIM
            " So skip the delimiter...
            let deformatted_text .= prefix . delim
            continue
        endif


        if delim =~ '^\(' . s:ESCAPED_CHAR . '\)$'
            " Escaped characters are literals, but without the escape...
            let deformatted_text .= prefix . delim[1]
            let offset += 1
            continue

        elseif delim =~ s:CODEEMPH_ONE_PAT
            " Singleton codeemph characters must remember the character...
            let deformatted_text .= prefix . delim[-5:-5]
            let offset += 8
            let one[codeemph] += [ strlen(deformatted_text) ]
            continue

        elseif delim =~ s:CODE_ONE_PAT
            " Singleton code characters must remember the character...
            let deformatted_text .= prefix . delim[-3:-3]
            let offset += 4
            let one[in_emph ? codeemph : code] += [ strlen(deformatted_text) ]
            continue

        elseif delim =~ s:EMPH_ONE_PAT
            if in_emph
                " Special 'off.on' case...
                let deformatted_text .= prefix . delim[-3:-3]
                let delim_startpos = strlen(deformatted_text)
                let offset += 4
                let end[in_code ? codeemph : emph]   += [ delim_startpos-1 ]
                let start[in_code ? codeemph : emph] += [ delim_startpos+1 ]

            else
                " Singleton emph characters must remember the character...
                let deformatted_text .= prefix . delim[-3:-3]
                let offset += 4
                let one[in_code ? codeemph : emph] += [ strlen(deformatted_text) ]
            endif
            continue

        else
            " Otherwise it's a formatting delimiter, so remove it...
            let deformatted_text .= prefix
            let delim_startpos = strlen(deformatted_text)
            let offset += strlen(delim)
        endif

        " And remember it...

        if delim =~ s:CODEEMPH_START_PAT
            let in_code += 1
            let in_emph = 1
            let start[codeemph] += [ delim_startpos+1 ]

        elseif delim =~ s:CODEEMPH_END_PAT
            let in_code -= 1
            let in_emph = 0
            let end[codeemph] += [ delim_startpos ]

        elseif delim =~ s:CODE_START_PAT
            let in_code += 1
            let start[in_emph ? codeemph : code] += [ delim_startpos+1 ]

        elseif delim =~ s:CODE_END_PAT
            let in_code = max([in_code-1, 0])
            let end[in_emph ? codeemph : code] += [ delim_startpos ]
            if in_emph
                let start[emph] += [ delim_startpos + 1 ]
            endif

        elseif delim =~ s:EMPH_START_PAT && !in_emph
            let in_emph = 1
            let start[in_code ? codeemph : emph] += [ delim_startpos+1 ]

        elseif delim =~ s:EMPH_END_PAT && in_emph
            let in_emph = 0
            let end[in_code ? codeemph : emph] += [ delim_startpos ]
            if in_code
                let start[code] += [ delim_startpos + 1 ]
            endif

        else
            throw 'Internal error: bizarre formatting delimiter ('.delim.')'
        endif

    endwhile

    " Fill in the gaps left by removing formatting delimiters...
    let left_fill  = external_offset + (is_centred  ?  offset/2 :  0)
    let right_fill = is_centred  ?  offset-left_fill  :  offset
    let deformatted_text = repeat(" ", left_fill)
    \                    . deformatted_text
    \                    . repeat(" ", right_fill)

    " Columns may need to be offset to compensate for removed delimiters...
    for format_type in keys(start)
        call map(start[format_type], 'v:val + left_fill')
        call map(end[format_type],   'v:val + left_fill')
        call map(one[format_type],   'v:val + left_fill')
    endfor

    return [ deformatted_text,
    \        { 'row': a:row+1, 'one': one, 'start': start, 'end': end }
    \      ]
endfunction

function! s:format_html (text, opt)
    let is_codeblock = get(a:opt, 'codeblock')
    let is_literal   = get(a:opt, 'literal')

    " Track locations and state within text
    let [in_emph, in_code] = [0,0]

    " Quote HTML special chars...
    let still_to_search = a:text
    let still_to_search = substitute(still_to_search, '&', '\&amp;', 'g')
    let still_to_search = substitute(still_to_search, '<', '\&lt;',  'g')
    let still_to_search = substitute(still_to_search, '>', '\&gt;',  'g')

    if is_literal
        return still_to_search
    endif

    " Set up markers...
    let [EM, unEM]
    \ = is_codeblock ? [ '<span class="VimpointCodeBlockEmph">', '</span>' ]
    \                : [ '<span class="VimpointEmph">',          '</span>' ]
    let [CODE, unCODE]
    \ = is_codeblock ? [ "",                                     ""        ]
    \                : [ '<span class="VimpointCode">',          '</span>' ]

    " Search through the line...
    let deformatted_text = ""
    while 1
        let matched = matchlist(still_to_search, s:FORMATTER_PAT)
        if empty(matched)
            let deformatted_text .= still_to_search
            break
        endif

        " What did we find?
        let [prefix, delim, still_to_search] = matched[1:3]

        " Apparent code delims inside a codeblock are really literals...
        if is_codeblock && delim =~ s:CODE_DELIM
            " So skip the delimiter...
            let deformatted_text .= prefix . delim
            continue
        endif

        if delim =~ '^\(' . s:ESCAPED_CHAR . '\)$'
            " Escaped characters are literals, but without the escape...
            let deformatted_text .= prefix . delim[1]
            continue

        elseif delim =~ s:CODEEMPH_ONE_PAT
            " Singleton codeemph characters must remember the character...
            let deformatted_text
            \   .= prefix . CODE . EM . delim[-5:-5] . unEM . unCODE
            continue

        elseif delim =~ s:CODE_ONE_PAT
            " Singleton code characters must remember the character...
            let deformatted_text
            \   .= prefix . CODE . delim[-3:-3] . unCODE
            continue

        elseif delim =~ s:EMPH_ONE_PAT
            " Singleton emph characters must remember the character...
            let deformatted_text
            \   .= prefix . EM . delim[-3:-3] . unEM
            continue

        elseif delim =~ s:CODEEMPH_START_PAT
            let deformatted_text .= prefix . EM . CODE
            let in_code += 1
            let in_emph = 1

        elseif delim =~ s:CODEEMPH_END_PAT
            let deformatted_text .= prefix . unCODE . unEM
            let in_code -= 1
            let in_emph = 0

        elseif delim =~ s:CODE_START_PAT
            let deformatted_text .= prefix . CODE
            let in_code += 1

        elseif delim =~ s:CODE_END_PAT
            let deformatted_text .= prefix . unCODE
            let in_code = max([in_code-1, 0])

        elseif delim =~ s:EMPH_START_PAT && !in_emph
            let deformatted_text .= prefix . EM
            let in_emph = 1

        elseif delim =~ s:EMPH_END_PAT && in_emph
            let deformatted_text .= prefix . unEM
            let in_emph = 0

        else
            throw 'Internal error: bizarre formatting delimiter ('.delim.')'
        endif
    endwhile

    return deformatted_text
endfunction

let NL = "\n"
let EOL = '\%(\%$\|'.NL.'\)'

let s:ON_PAT                = '\(\s\+on\|\s\+1\|\s\+enable\|\s\+yes\|\s*$\)'
let s:HEADER_PAT            = '^\([^-+=* \t]\|\*\*\)'
let s:SECTION_PAT           = '^=section\(\s\+\|$\)'
let s:PAUSE_PAT             = '^=pause'
let s:AUTOPAUSE_PAT         = '^=autopause'
let s:AUTOPAUSE_ON_PAT      = '^=autopause' . s:ON_PAT
let s:AUTOSLIDEPAUSE_PAT    = '^=autoslidepause'
let s:AUTOSLIDEPAUSE_ON_PAT = '^=autoslidepause' . s:ON_PAT
let s:BREAK_PAT             = '^=break'
let s:ANIMATION_PAT         = '^=animation'
let s:TARGET_PAT            = '^=target\ze\s\+\S'
let s:LINK_PAT              = '^=link\ze\s\+\S'
let s:METAINFO_PAT          = '^=\(title\|presenter\|info\|duration\)'
let s:ACTIVE_FILE_PAT       = '^=active\ze\s\+\S'
let s:ACTIVE_PAT            = '^=active'
let s:EXAMPLE_FILE_PAT      = '^=example\ze\s\+\S'
let s:EXAMPLE_PAT           = '^=example'
let s:INTERMISSION_PAT      = '^=intermission'
let s:SELECTOR_PAT          = '^=selector\s\+\(\S\+\)\s\+\(\(.\).*\)'
let s:DURATION_PAT          = '^=duration\ze\s\+\S'
let s:NOTES_ONLY_PAT        = '^+\s'
let s:SLIDES_ONLY_PAT       = '^-\s'
let s:LEADING_BULLET_PAT    = '^\*\s\@='
let s:COMMENT_PAT           = '^!'

" Suggested bullet characters (stick with Latin-1)
let s:LEADING_BULLET         = '»'
let s:LEADING_BULLET         = '×'
let s:LEADING_BULLET         = '¤'
let s:LEADING_BULLET         = '·'

let s:BUILD_SLIDE = {
\   'vps': function('s:create_vps_file'),
\   'vpa': function('s:create_vpa_file'),
\   'vpi': function('s:create_vpi_file'),
\   'vpf': function('s:create_vpf_file'),
\   'vpe': function('s:create_vpe_file'),
\   'vpd': function('s:create_vpd_file'),
\}

let s:BUILD_HTML = {
\   'vpa': function('s:create_vpa_html'),
\   'vps': function('s:create_vps_html'),
\   'vpi': function('s:create_vpi_html'),
\   'vpf': function('s:create_vpf_html'),
\   'vpe': function('s:create_vpe_html'),
\   'vpd': function('s:create_vpd_html'),
\}


function! s:run (duration, ...)
    let offset = a:0 && strlen(a:1) ? line('.') - 1 : 0

    " If duration specified, convert from minutes to seconds...
    if a:duration
        let duration = a:duration - offset
        let g:VimpointRunDuration = duration * 60
        echo 'Running for ' . duration . ' minute' . (duration>1 ? 's' : "")
        redraw
        sleep 3
        return
    endif

    " Recompile (if necessary)...
    call s:compile()

    " Clean up any match highlighting...
    nohlsearch

    " Jump to title slide...
    let presname = expand('%:p:r') . '.vpp/*'
    execute 'next ' . presname
endfunction

function! s:edit_specification ()
    if exists('b:vpt')
        let context = b:vpt
        let slide_num = exists("t:Vimpoint_currfile")
                    \ ? matchstr(t:Vimpoint_currfile, '.*/\zs\d\+')
                    \ : context.slide_number
        let slide = expand('%:h') . '/' . slide_num . '*'
        execute 'next ' . context.file
        execute 'normal ' . context.line . 'G'
        execute 'command! -buffer  Resume  :call s:resume_presentation("' . slide. '")'
    else
        echo "Can't locate source file"
    endif
endfunction

function! s:resume_presentation (filename)
    echo 'Resuming...'
    sleep 1
    Compile
    delcommand Resume
    execute "call s:goto_slide_file(glob('" . a:filename . "'))"
    nohlsearch
endfunction

function! s:intermit (duration, ...)

    " Decode the requested duration and convert to seconds...
    let offset = a:0 && strlen(a:1) ? line('.') - 1 : 0
    let duration = a:duration - offset
    let duration = duration > 0 ? duration * 60 : ""

    " Build a temporary intermission file...
    let filename
    \ = s:create_vpi_file('TMP',
    \                     b:vpt.pres,
    \                     { 'duration':duration, 'context':{} },
    \                     getcwd()
    \   )

    " And edit it
    let normalfile = expand('%:p:r')
    execute 'write! '  . normalfile
    execute 'tabedit ' . filename
    echo " "
    redraw
endfunction

function! VimpointEditSlideCopy ()
    let normalfile = expand('%:p:r')
    execute 'write! '  . normalfile
    execute 'tabedit ' . normalfile
    %s/\s*$//
    $s/.*//
    source $MYVIMRC
    normal 1G
endfunction

function! VimpointEditScratchpad ()
    let normalfile = tempname()
    execute 'tabedit ' . normalfile
endfunction

function! VimpointNextFile (incr, unit)
    " Where are we now?
    let currfile   = exists("t:Vimpoint_currfile") ? t:Vimpoint_currfile : simplify(expand('%'))
    let currdir    = expand('%:h')
    let slides     = a:unit=='slide'
    \                   ? split(glob(currdir.'/*.vp[as]'), "\n")
    \                   : split(glob(currdir.'/*.vp[asfie]'), "\n")
    let currloc    = index(slides, currfile)

    " Where next?
    let nextloc
      \ = a:unit=='advance'
      \      ? currloc + a:incr
      \ : a:unit=='slide' && a:incr<0 && currloc > 0 && currfile !~ '/\d\+\._'
      \      ? match(reverse(slides), '/\d\+\._', -currloc, 2)
      \ : a:unit=='slide' && a:incr<0 && currloc > 0
      \      ? match(reverse(slides), '/\d\+\._', -currloc)
      \ : a:unit=='slide' && a:incr>0
      \      ? match(        slides , '/\d\+\._', currloc+1)
      \ :      -1

    " Go there (if "there" exists)
    if nextloc >= 0
        let newfile = get(slides,nextloc,currfile)
        call s:goto_slide_file(newfile)
    endif
endfunction

" Show requested slide, remember its name, and clean up prev buffer...
function! s:goto_slide_file (newfile)
        let t:Vimpoint_currfile = a:newfile
        execute "next! " . t:Vimpoint_currfile
        execute "normal 0"
        execute "try | bdelete # | catch | endtry"
endfunction

function! VimpointFindTarget (show_what)

    " Find current context
    let currdir      = expand('%:p:h')
    let currfiletype = expand('%:e')
    let currfile     = expand('%:t')
    let currslidenum = strpart(currfile,0,g:Vimpoint_SLIDE_NUMBER_SIZE)

    " Find all targets
    let target_names  = []
    let response_for  = {}

    " Assemble potential targets...
    let file_for = get(s:load_metadata_for(glob(currdir . '/*.vpf')), 'all_targets', {})

    " Exclude current slide...
    call filter(file_for, 'v:val != currslidenum')

    " Build list of targets and action to be executed...
    for target in keys(file_for)
        let target_names = target_names + [ file_for[target] . '.' . target ]
        let response_for[target]
        \   = "call s:goto_slide_file(glob('" . currdir . '/' . file_for[target] . "*'))"
    endfor

    " Sort target names by their slide position in the presentation...
    call sort(target_names)
    call map(target_names, 'strpart(v:val,g:Vimpoint_SLIDE_NUMBER_SIZE+1)')

    " If appropriate, remove any slides before the current slide...
    if a:show_what == 'next'
        call filter(target_names, 'file_for[v:val] > currslidenum')
    endif

    " If there are links on this slide...
    if !empty(get(b:vpt,'links',{}))
        " Keep only those targets...
        call filter(target_names, 'has_key(b:vpt.links, v:val)')

        " Resolve and prepend in any external links...
        let external_links = filter(keys(b:vpt.links), "v:val =~ '\.vpp$'")
        for filename in external_links
            let file_for[filename]     = filename
            let response_for[filename] = 'tab next ' . filename . '/*.vp[safie]'
        endfor
        let target_names = external_links + target_names

        let has_links = 1
    else
        let has_links = 0
    endif

    " If no targets, we're done...
    if empty(target_names)
        echo "No targets available"
        sleep 2
        return

    " Jump straight to a link if it's unique...
    elseif a:show_what == 'next' && has_links && len(target_names) == 1
        try
            execute response_for[target_names[0]]
            normal 1G
        catch
            redraw
            echo "Couldn't jump to " . target_names[0]
            sleep 2
        endtry

    " Jump straight to next target if requested...
    elseif a:show_what == 'next' && !has_links
        if len(target_names) > 0
            try
                execute response_for[target_names[0]]
                normal 1G
            catch
                redraw
                echo "Couldn't jump to " . target_names[0]
                sleep 2
            endtry
        else
            redraw
            echo "No targets available"
            sleep 2
            return
        endif

    " Otherwise, select a target...
    else
        while 1
            redraw

            " Prompt with current candidate...
            echo target_names[0] =~ '\.vpp$'
            \       ?  '['.target_names[0].']'
            \       :  '<'.target_names[0].'>'
            let raw_response = getchar()
            let response = nr2char(raw_response)

            " Tab --> next candidate (by rotating them)...
            if response == "\t"
                let target_names += [remove(target_names, 0)]

            " Shift-tab --> previous candidate (by rotating)...
            elseif raw_response == "\<S-TAB>"
                let target_names = [remove(target_names, -1)] + target_names

            " Return --> select this candidate...
            elseif response == "\r"
                try
                    execute response_for[target_names[0]]
                    normal 1G
                catch
                    redraw
                    echo "Couldn't jump to " . target_names[0]
                    sleep 2
                endtry
                break

            " Anything else --> cancel the jump...
            else
                echo "  "
                break
            endif
        endwhile
    endif
    echon ' '
    redraw
endfunction


function! s:build_docmodel (...)
    let opt = a:0 ? a:1 : {}
    let is_dynamic = get(opt, 'dynamic')
    let s:all_targets = {}

    " Track multiline states...
    let [in_heading, in_metainfo, in_directive, post_directive] = [0,"",0,1]
    let newslide = 0

    " Global information regarding the presentation...
    let pres = { 'title': [], 'presenter':[], 'info':[], 'autopause': 0 }
    let [autopause, autoslidepause] = [0, 1]

    " Track slide context so presentation files can use :Specification...
    let context = { 'file': expand('%:p'), 'line': 1, 'targets':{}, 'links':{}, 'selector_links':{}, 'selector_texts':{} }

    " Initialize the document model with an intro slide...
    let docmodel = [{
    \   'type': 'vpf',
    \   'context': deepcopy(context),
    \   'content': [],
    \}]
    let context.line = 0

    let section_count = 1

    for line in getline(1,'$')
        " Track line number...
        let context.line += 1

        " Normalize blank lines...
        let line = substitute(line, '^\s*$', "", "")

        " Preprocess + and - lines...
        if line =~ s:SLIDES_ONLY_PAT
            if is_dynamic
                let line = substitute(line, s:SLIDES_ONLY_PAT, "", "")
            else
                let in_directive = 1
                continue
            endif
        elseif line =~ s:NOTES_ONLY_PAT
            if !is_dynamic
                let line = substitute(line, s:NOTES_ONLY_PAT, "", "")
            else
                let in_directive = 1
                continue
            endif
        endif

        " Preprocess a =selector (track the link and convert to a bullet point
        if line =~ s:SELECTOR_PAT
            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

            " Extract and save selector data...
            let [ignored, link_name, line, selector_key; ignored_too] = matchlist(line, s:SELECTOR_PAT)
            let docmodel[-1].context.selector_links[selector_key] = link_name
            let docmodel[-1].context.selector_texts[selector_key] = line

            " Add bullet to selector text...
            let line = '* ' . line

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

        endif

        " Ignore comments...
        if line =~ s:COMMENT_PAT
            continue

        " Locate a section...
        elseif line =~ s:SECTION_PAT
            let line = substitute(line, s:SECTION_PAT, "", "")

            if line =~ '\([^\\]\|^\)\zs#'
                let line = substitute(line, '\([^\\]\|^\)\zs#', section_count, "")
                let section_count += 1
            endif
            let line = substitute(line, '\\', '', 'g')

            let docmodel += [{
            \    'type':    'vps',
            \    'title':   [ line ],
            \    'content': [],
            \    'context': deepcopy(context),
            \    'first':   1,
            \}]
            let docmodel += [{
            \    'type':    'vpa',
            \    'title':   [ line ],
            \    'content': [],
            \    'context': deepcopy(context),
            \    'first':   -1,
            \}]
            let autopause  = pres.autopause

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     1,          "",           0,             0      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif

        " Locate a heading...
        elseif line =~ s:HEADER_PAT && in_heading
            let docmodel[-1].title += [ line ]

        elseif line =~ s:HEADER_PAT
            let docmodel += [{
            \    'type':    'vpa',
            \    'title':   [ line ],
            \    'content': [],
            \    'context': deepcopy(context),
            \    'first':   1,
            \}]
            let autopause  = pres.autopause

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     1,          "",           0,             0      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif

        " Locate a =title, =presenter, or =info
        elseif line =~ s:METAINFO_PAT
            let components = matchlist(line, s:METAINFO_PAT)
            let type = components[1]
            let pres[type]
                \= [ substitute(line, s:METAINFO_PAT . '\s\+\|\s\+$', "", "") ]

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,         type,          1,             0      ]

        " Locate an =autoslidepause...
        elseif line =~ s:AUTOSLIDEPAUSE_PAT
            let autoslidepause = match(line, s:AUTOSLIDEPAUSE_ON_PAT) >= 0

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

        " Locate an =autopause
        elseif line =~ s:AUTOPAUSE_PAT
            " At start of document, applies to every slide...
            if docmodel[-1].type == 'vpf'
                let pres.autopause = match(line, s:AUTOPAUSE_ON_PAT) >= 0

            " Otherwise, just the current slide
            else
                let autopause = match(line, s:AUTOPAUSE_ON_PAT) >= 0

                " If autopause activated, insert a pause as well...
                if autopause && is_dynamic && docmodel[-1].type == 'vpa'
                    " Duplicate last slide state...
                    let docmodel += [ deepcopy(docmodel[-1]) ]

                    " Modify to reflect that it's a different file...
                    let docmodel[-1].first = 0
                endif

            endif

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
             \= [     0,          "",           0,             1      ]

        " Locate a =pause
        elseif line =~ s:PAUSE_PAT
            if is_dynamic && docmodel[-1].type =~ 'vpa'
                " Duplicate last slide state...
                let docmodel   += [ deepcopy(docmodel[-1]) ]

                " Modify to reflect that it's a different file...
                let docmodel[-1].first  = 0
            endif

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

        " Locate a =break
        elseif line =~ s:BREAK_PAT
            if is_dynamic && docmodel[-1].type =~ 'vpa'
                " Duplicate last slide state...
                let docmodel   += [ deepcopy(docmodel[-1]) ]

                " Modify to reflect that it's a different file and content...
                let docmodel[-1].first                  = 0
                let docmodel[-1].content                = []
                let docmodel[-1].context.line           = context.line
                let docmodel[-1].context.links          = {}
                let docmodel[-1].context.selector_links = {}
                let docmodel[-1].context.selector_texts = {}
                let docmodel[-1].context.targets        = {}
            endif

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif

        " Locate an =animation
        elseif line =~ s:ANIMATION_PAT
            if is_dynamic && docmodel[-1].type =~ 'vpa'
                if !exists('animation_prefix')
                    " At start of animation: remember last slide state...
                    let animation_prefix = deepcopy(docmodel[-1])

                    " Insert an autopause, if one is required...
                    if is_dynamic && autopause && !empty(docmodel[-1].content)
                        let docmodel += [ deepcopy(docmodel[-1]) ]
                        let docmodel[-1].first  = 0
                    endif
                else
                    " From second frame on: copy last slide state...
                    let docmodel += [ deepcopy(animation_prefix) ]

                    " Modify to reflect that it's a different file...
                    let docmodel[-1].first = 0
                endif
            elseif !is_dynamic
                let in_animation = line !~ 'keyframe'
            endif

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

        " Locate a =link
        elseif line =~ s:LINK_PAT
            let link_name = s:trim_text(strpart(line,matchend(line,s:LINK_PAT)))
            let docmodel[-1].context.links[link_name] = 1

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

        " Locate a =target
        elseif line =~ s:TARGET_PAT
            let target_name
            \   = s:trim_text(strpart(line,matchend(line,s:TARGET_PAT)))
            let docmodel[-1].context.targets[target_name] = 1
            let s:all_targets[target_name]
            \   = printf('%0*d', g:Vimpoint_SLIDE_NUMBER_SIZE, len(docmodel)-1)

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

        " Locate an =active with filename
        elseif line =~ s:ACTIVE_FILE_PAT
            let active_source
            \   = s:trim_text(strpart(line,strlen(s:ACTIVE_PAT)-1))
            let docmodel += [{
            \   'type':      'vpd',
            \   'source':    active_source,
            \   'title':     [ active_source ],
            \   'context':   deepcopy(context),
            \   'first':     1,
            \   'content':   [],
            \   'is_active': 1
            \}]

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif

        " Locate an =example with filename
        elseif line =~ s:EXAMPLE_FILE_PAT
            let example_source
            \   = s:trim_text(strpart(line,strlen(s:EXAMPLE_PAT)-1))
            let docmodel += [{
            \   'type':     'vpd',
            \   'source':   example_source,
            \   'title':    [ example_source ],
            \   'context':  deepcopy(context),
            \   'first':    1,
            \   'content':  [],
            \}]

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif

        " Locate an =example without filename
        elseif line =~ s:EXAMPLE_PAT
            let docmodel += [{
            \   'type':     'vpe',
            \   'source':   expand("%:p"),
            \   'context':  deepcopy(context),
            \   'first':    1,
            \   'content':  [],
            \}]

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif

        " Locate an =intermission
        elseif line =~ s:INTERMISSION_PAT
            let docmodel += [{
            \   'type':     'vpi',
            \   'duration': strpart(line,strlen(s:INTERMISSION_PAT)-1),
            \   'context':  deepcopy(context),
            \   'first':    1,
            \   'content':  [],
            \}]

            " Track multiline status...
            let [in_heading, in_metainfo, in_directive, post_directive]
            \= [     0,          "",           0,             1      ]

            " Cancel any existing animation sequence...
            let in_animation = 0
            if exists('animation_prefix')
                unlet animation_prefix
            endif


        " Empty line terminates heading or directive...
        elseif  line !~ '\S' && (in_heading || in_directive || post_directive)
            let [in_heading, in_metainfo, in_directive, post_directive]
             \= [     0,          "",           0,             1      ]

        " Non-empty line may be more heading...
        elseif line =~ '\S' && in_heading
            let docmodel[-1].title += [line]

        " Or more metainformation (title, presenter, or info)
        elseif strlen(in_metainfo)
            let pres[in_metainfo] += [line]

        " Or post-directive noise or whitespace...
        elseif in_directive || line !~ '\S' && post_directive
            continue

        " Or animation that a handout should ignore...
        elseif !is_dynamic && in_animation
            continue

        " Otherwise it's content...
        else
            " If current slide not an advance
            " or if it's an inline example and the content is from column 1
            " treat it as an implied break to the most recent advance slide...
            if docmodel[-1].type !~ 'vp[ae]'
            \  || docmodel[-1].type == 'vpe' && line =~ '^\S'
                let index = len(docmodel)-2
                while index > 0
                    if docmodel[index].type == 'vpa'
                        let docmodel += [ deepcopy(docmodel[index]) ]
                        let docmodel[-1].first                   = 0
                        let docmodel[-1].content                 = []
                        let docmodel[-1].context.links           = {}
                        let docmodel[-1].context.selector_links  = {}
                        let docmodel[-1].context.selector_texts  = {}
                        let docmodel[-1].context.targets         = {}
                        break
                    endif
                    let index -= 1
                endwhile
            endif

            " Insert any autoslidepause before first content of new slides...
            if is_dynamic
            \&& autoslidepause
            \&& docmodel[-1].type == 'vpa'
            \&& line =~ '\S'
            \&& docmodel[-1].first
            \&& empty(docmodel[-1].content)
                let docmodel += [ deepcopy(docmodel[-1]) ]
                let docmodel[-1].first  = 0
                let docmodel[-1].type   = 'vpa'

            " Non-initial, non-empty content lines trigger autopauses...
            elseif is_dynamic
            \   && autopause
            \   && !post_directive
            \   && line !~ '^\s'
            \   && line =~ '\S'
            \   && !empty(docmodel[-1].content)
            \   && docmodel[-1].content[-1] !~ '\S'
                " Add partial slide to document model
                let docmodel += [ deepcopy(docmodel[-1]) ]
                let docmodel[-1].first  = 0
            endif

            " Add content, converting markup bullets to normal (or no) bullets...
            let line = substitute(line, s:LEADING_BULLET_PAT, s:LEADING_BULLET, "")
            let docmodel[-1].content += [ line ]

            " Track multi-line status...
            let [in_heading, in_metainfo, in_directive, post_directive]
             \= [     0,          "",           0,            0       ]
        endif

    endfor

    return [pres, docmodel]
endfunction

function! s:compile ()
    " Save any unsaved changes...
    if &modified
        write
    endif

    " Locate presentation directory and compare dates
    let srcname = expand('%')
    let dirname = expand('%:p:r') . '.vpp'
    if getftime(srcname) < getftime(dirname)
        return
    endif

    " Extract document model and presentation metainformation
    let [pres, docmodel] = s:build_docmodel({ 'dynamic': 1 })

    " Build, clear, and enter the presentation directory...
    if !isdirectory(dirname)
        call mkdir(dirname)
    endif
    for file in split(glob(dirname.'/*'), "\n")
        call delete(file)
    endfor

    execute 'cd ' . dirname
    " Note: using Vim's built-in chdir(), not system's...

    " Then emit slide files by converting document model entries...
    let slidecount = len(docmodel)
    for slidenum in range(slidecount)
        let percentage = slidenum*100 / slidecount
        echo printf("[%-50s] %3d%%", repeat('|',percentage/2), percentage)
        redraw
        let slide = docmodel[slidenum]
        let slide.context.pres = pres
        call call(s:BUILD_SLIDE[slide.type], [slidenum, pres, slide, dirname])
    endfor

    " Clean up progress bar...
    echo " "

    " Return to original directory...
    cd -

endfunction

function! s:handout ()
    " Extract document model and presentation metainformation
    let [pres, docmodel] = s:build_docmodel()

    " Start by building html file...
    let filename = expand('%:p:r') . '.html'

    " Then build HTML lines by converting document model entries...
    let html = s:html_static_header( join(pres.title," ") )
    let slidecount = len(docmodel)
    let pres.prev_title = []
    for slidenum in range(slidecount)
        let slide = docmodel[slidenum]
        let percentage = slidenum*100 / slidecount
        echo printf("[%-50s] %3d%%", repeat('|',percentage/2), percentage)
        redraw
        let slide.context.pres = pres
        let html += call(s:BUILD_HTML[slide.type], [slidenum, pres, slide])
        let pres.prev_title = get(slide, 'title', pres.prev_title)
    endfor
    let html += ['</body>', '</html>']

    " Clean up progress bar...
    echo " "

    " Create the HTML file...
    call writefile(html, filename)
endfunction

function! s:html_static_header (title)
    return [
    \       '<head>',
    \       '<title>' . a:title . '</title>',
    \       '<style type="text/css">',
    \       '<!--',
    \       'p {',
    \       '    margin: 0pt ;',
    \       '}',
    \       'p.VimpointPresTitle {',
    \       '    font-family:    Times  ;',
    \       '    font-size:      18pt   ;',
    \       '    font-style:     bold   ;',
    \       '    text-align:     center ;',
    \       '    margin-bottom:  24pt   ;',
    \       '}',
    \       'p.VimpointPresName {',
    \       '    font-family:    Times  ;',
    \       '    font-size:      15pt   ;',
    \       '    font-style:     bold   ;',
    \       '    text-align:     center ;',
    \       '    margin-bottom:  18pt   ;',
    \       '}',
    \       'p.VimpointPresInfo {',
    \       '    font-family:    Times  ;',
    \       '    font-size:      13pt   ;',
    \       '    font-style:     normal ;',
    \       '    text-align:     center ;',
    \       '    margin-bottom:  36pt   ;',
    \       '}',
    \       'p.VimpointSectionTitle {',
    \       '    font-family:    Times  ;',
    \       '    font-size:      18pt   ;',
    \       '    font-weight:    bold   ;',
    \       '    margin-top:     36pt   ;',
    \       '    margin-bottom:  0pt    ;',
    \       '}',
    \       'p.VimpointSlideTitle {',
    \       '    font-family:    Times  ;',
    \       '    font-size:      16pt   ;',
    \       '    font-weight:    bold   ;',
    \       '    margin-top:     36pt   ;',
    \       '    margin-bottom:  0pt    ;',
    \       '}',
    \       'li.VimpointSlideBullet {',
    \       '    font-family:    Times  ;',
    \       '    font-size:      12pt   ;',
    \       '    font-weight:    normal ;',
    \       '    margin-top:     8pt    ;',
    \       '}',
    \       'p.VimpointSlideCodeBlock {',
    \       '    white-space:    pre     ;',
    \       '    font-family:    Courier ;',
    \       '    font-size:      11pt    ;',
    \       '    font-weight:    normal  ;',
    \       '    line-height:    13pt    ;',
    \       '    margin-top:     8pt     ;',
    \       '    margin-left:    1cm     ;',
    \       '}',
    \       'p.VimpointExample {',
    \       '    border:         medium double ;',
    \       '    white-space:    pre           ;',
    \       '    font-family:    Courier       ;',
    \       '    font-size:      11pt          ;   ',
    \       '    font-weight:    normal        ; ',
    \       '    line-height:    13pt          ; ',
    \       '    padding:        0.5cm 1cm     ;',
    \       '}',
    \       'p.VimpointExampleCaption {',
    \       '    font-family:    Helvetica  ;',
    \       '    font-size:      16pt       ;',
    \       '    font-weight:    bold       ;',
    \       '    margin-top:     36pt       ;',
    \       '    margin-bottom:  0pt        ;',
    \       '}',
    \       'span.VimpointEmph {',
    \       '    font-style:     italic     ;',
    \       '}',
    \       'span.VimpointCodeBlockEmph {',
    \       '    font-weight:    bold       ;',
    \       '}',
    \       'span.VimpointCode {',
    \       '    font-family:    Courier    ;',
    \       '}',
    \       '-->',
    \       '</style>',
    \       '</head>',
    \       '<body>',
    \ ]
endfunction

"============================================================================

" Timer for intermission slides
function! VimpointIntermissionTimer (duration)
    " Clear the statusline...
    echo "  "

    " Decode duration (translate hrs and mins to seconds)
    let matches = matchlist(a:duration, '\(\d\+\)\s*\([smh]\?\)')
    if !len(matches)
        return
    elseif matches[2] == 'h'
        let countdown = matches[1] * 3600
    elseif matches[2] == 'm'
        let countdown = matches[1] * 60
    else
        let countdown = matches[1]
    endif

    " Locate title...
    let title_row = getline(g:Vimpoint_INTERMISSION_TITLE_ROW+1)

    " Ignore any queued commands...
    call inputsave()

    " Count downwards...
    try
        " Loop until user presses any key...
        while 1
            let input = getchar(1)
            if input
                let cmd = nr2char(input)
                if cmd =~ '[-_]'
                    " Advance countdown by 1 minute
                    let countdown -= 60
                    call getchar()
                elseif cmd =~ '[+=]'
                    " Add a 1 minute to countdown
                    let countdown += 60
                    call getchar()
                else
                    " Any other command terminates the timer...
                    break
                endif
            endif

            " Select appropriate message and pause, depending on time remaining
            if countdown > 60
                let mins = (countdown+30) / 60
                let msg = 'will resume in about ' . (mins != 1 ? mins : 'a')
                           \ . ' minute' . (mins != 1 ? 's' : "")
            elseif countdown > 0
                let secs = countdown
                let msg = 'will resume in ' . secs
                          \ . ' second' . (secs != 1 ? 's' : "")
            elseif countdown > -30
                let msg = 'will resume now'
            elseif countdown > -200
                let msg = 'will resume any minute now'
            else
                let msg = 'should resume shortly'
            endif

            " Display message
            call setline(g:Vimpoint_INTERMISSION_TITLE_ROW+2,
                        \printf("%-*s", g:Vimpoint_DEFAULT_COLS-1,
                        \       s:create_centred_on_title(title_row, msg))
                        \)
            call s:trim_right_edge()
            redraw

            sleep 1
            let countdown -= 1
        endwhile
    catch /^Vim:Interrupt$/
    finally
        call setline(g:Vimpoint_INTERMISSION_TITLE_ROW+2,
                    \s:create_centred_on_title(title_row, 'will resume now'))
        call s:trim_right_edge()
        redraw
    endtry

    " Ignore any typeahead that occured during the timer...
    "call inputrestore()

    return
endfunction

"============================================================================

" Restore previous external compatibility options
let &cpo = s:save_cpo
