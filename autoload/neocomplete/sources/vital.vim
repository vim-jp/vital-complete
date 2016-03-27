"=============================================================================
" FILE: autoload/neocomplete/sources/vital.vim
" AUTHOR: haya14busa
" License: MIT license
"=============================================================================
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:source = {
\   'name': 'vital',
\   'kind': 'manual',
\   'input_pattern': '\h\w*\.\?',
\   'filetypes': {'vim': 1 },
\ }

function! s:source.get_complete_position(context)
  return vital_complete#find_start_col()
endfunction

function! s:source.gather_candidates(context)
  let ctx = vital_complete#context()
  return vital_complete#completion_items(ctx, a:context.complete_str)
endfunction

function! neocomplete#sources#vital#define() abort
  return s:source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" __END__
" vim: expandtab softtabstop=2 shiftwidth=2 foldmethod=marker
