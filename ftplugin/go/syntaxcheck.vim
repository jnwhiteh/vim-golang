" syntaxcheck.vim - A script to highlight syntax errors in Go code

if exists("b:did_golang_scheck_plugin")
    finish
else
    let b:did_golang_scheck_plugin = 1
endif

" Some options defaults
if !exists("g:golang_scheck_tool")
    let g:golang_scheck_tool = "gotype"
    if !executable("gotype")
        finish " we're crippled without gotype, so bail out
    endif
endif

" WideMsg() prints [long] message up to (&columns-1) length
" guaranteed without "Press Enter" prompt.
if !exists("*s:WideMsg")
    function s:WideMsg(msg)
        let x=&ruler | let y=&showcmd
        set noruler noshowcmd
        redraw
        echo strpart(a:msg, 0, &columns-1)
        let &ruler=x | let &showcmd=y
    endfun
endif

au BufReadPost <buffer> call s:RunGolangScheck()
au BufWritePost <buffer> call s:RunGolangScheck()

au CursorHold <buffer> call s:GetGolangScheckMsg()
au CursorMoved <buffer> call s:GetGolangScheckMsg()

if !exists("*s:RunGolangScheck")
    function s:RunGolangScheck()
        highlight link GolangErr SpellBad

        if exists("b:cleared")
            if b:cleared == 0
                silent call s:ClearGolangScheck()
                let b:cleared = 1
            endif
        else
            silent call s:ClearGolangScheck()
            let b:cleared = 1
        endif

        " Execute the syntax checking tool and let a list of errors
        let Cmd = shellescape(g:golang_scheck_tool, 1) . " " . shellescape(expand("%:p:h"), 1)
        silent! let results = system(Cmd)

        let b:matchedlines = {}

        " Using scriptnames-dictionary as an example
        for line in split(results, "\n")
            let err = matchlist(line, '\v(.*):(\d*):(\d*): (.+)$')
            if !empty(err)
                let [fname, lnum, cnum, msg] = err[1:4]
                if fname == expand("%:p")
                    let tokenpat = '\%' . lnum . 'l\%' . cnum . 'c\S*'
                    let m = matchadd('GolangErr', tokenpat)
                    " If this is for fname, then highlight the first non-space
                    " token of the file on the given line/column and make it
                    " squiggly.
                    if !has_key(b:matchedlines, lnum)
                        let b:matchedlines[lnum] = []
                    endif

                    let b:matchedlines[lnum] = [[cnum, msg]] + b:matchedlines[lnum]
                endif
            endif
        endfor

        let b:cleared = 0
    endfunction
end

if !exists('*s:ClearGolangScheck')
    function s:ClearGolangScheck()
        let s:matches = getmatches()
        for s:matchId in s:matches
            if s:matchId['group'] == 'GolangErr'
                call matchdelete(s:matchId['id'])
            endif
        endfor
        let b:matchedlines = {}
        let b:cleared = 1
    endfunction
endif

if !exists('*s:GetGolangScheckMsg')
    function s:GetGolangScheckMsg()
        let s:cursorPos = getpos(".")

        " Bail if the scan hasn't been called yet
        if !exists('b:matchedlines')
            return
        endif

        " If there's a message where the cursor currently is, echo it
        if has_key(b:matchedlines, s:cursorPos[1])
            let s:matches = get(b:matchedlines, s:cursorPos[1])
            for item in s:matches
                " This relies on the first item in the list >= our current
                " column being the error we are on. Hopefully this is
                " reasonable.
                if s:cursorPos[2] >= item[0]
                    call s:WideMsg(item[1])
                    break
                endif
            endfor
        endif
    endfunction
endif

