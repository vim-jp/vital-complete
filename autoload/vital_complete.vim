"=============================================================================
" FILE: autoload/vital_complete.vim
" AUTHOR: haya14busa
" License: MIT license
"=============================================================================
scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#vital_complete#of()
let s:File = s:V.import('System.File')
let s:Message = s:V.import('Vim.Message')
let s:ScriptLocal = s:V.import('Vim.ScriptLocal')
let s:Dict = s:V.import('Data.Dict')

let g:vital_complete#max_search_line = get(g:, 'vital_complete#max_search_line', 500)

" for :h omnifunc
" setlocal omnifunc=vital_complete#complete
function! vital_complete#complete(findstart, base) abort
  if a:findstart
    return vital_complete#find_start_col()
  endif
  return vital_complete#completion_items(s:context(), a:base)
endfunction

function! vital_complete#manual_complete()
  let idx = vital_complete#find_start_col()
  if idx < 0
    return ''
  endif
  let col = idx + 1
  let base = getline('.')[idx : col('.')-1]
  call complete(col, vital_complete#complete(0, base))
  return ''
endfunction

function! vital_complete#update(plugin_name) abort
  let data = s:update_plugin_data(a:plugin_name)
  if empty(data)
    call s:Message.error(printf('vital-complete: plugin data is empty. Run :Vitalize may fix this problem: %s', a:plugin_name))
    return
  endif
  call s:Message.echomsg('MoreMsg', printf('vital-complete: update plugin data: %s', a:plugin_name))
endfunction

function! vital_complete#context() abort
  return s:context()
endfunction

function! s:context() abort
  let line = getline('.')
  let col = col('.')
  let list = matchlist(line[: col - 1], '\(\([sg]:\)\=\(\w\+\)\)\.\(\w*\)$')
  if empty(list)
    return {}
  endif
  let [_, module_with_prefix, prefix, module, method_typed; __] = list
  return {
  \   'module_with_prefix': module_with_prefix,
  \   'start_col': col - len(method_typed) - 1,
  \ }
endfunction

function! vital_complete#find_start_col() abort
  let ctx = s:context()
  if empty(ctx)
    return -1
  endif
  return ctx.start_col
endfunction

function! vital_complete#completion_items(ctx, base) abort
  if empty(a:ctx)
    return []
  endif

  let plugin_name = s:plugin_name_from_buffer()
  if plugin_name is# ''
    return []
  endif

  let plugin_data = s:plugin_data(plugin_name)
  if empty(plugin_data)
    return []
  endif
  let modules = s:list_imports()
  if !has_key(modules, a:ctx.module_with_prefix)
    return []
  endif
  let module_name = modules[a:ctx.module_with_prefix]
  let module_data =  get(plugin_data, module_name, {})
  let funcs = keys(module_data)
  let matched_funcs = filter(copy(funcs), 'v:val =~# "^" . a:base')
  let items = []
  for funcname in matched_funcs
    let func_data = module_data[funcname]
    let menu = s:menu(module_name, funcname, func_data.args, func_data.attrs)
    let items += [{
    \   'word': funcname,
    \   'menu': menu,
    \ }]
  endfor
  return items
endfunction

function! s:menu(module_name, funcname, args, attrs) abort
  return printf('%s.%s(%s) %s',
  \   a:module_name,
  \   a:funcname,
  \   join(a:args, ', '),
  \   join(a:attrs, ' ')
  \ )
endfunction

function! s:plugin_name_from_buffer() abort
  let pattern = 'vital#\zs\w\+\ze#\%(of\|import\)\|vital#of(["'']\zs\w\+\ze["''])'
  for line in getline(1, g:vital_complete#max_search_line)
    let name = matchstr(line, pattern)
    if name !=# ''
      return name
    endif
  endfor
  return ''
endfunction

" @returns {{<var>: <module_name>}}
function! s:list_imports() abort
  let d = {}
  let pattern = '\vlet\s+(%([sg]:)?\w+)\s*\=.{-}[.#]import\(["''](\u%(\w+%(\.=))+)["'']\)'
  for line in filter(getline(1, g:vital_complete#max_search_line), 'v:val =~# pattern')
    let [_, var, module; __] = matchlist(line, pattern)
    let d[var] = module
  endfor
  return d
endfunction

let s:data_cache = {}
function! s:plugin_data(plugin_name) abort
  if has_key(s:data_cache, a:plugin_name)
    return s:data_cache[a:plugin_name]
  endif
  let data_path = s:data_path(a:plugin_name)
  if !filereadable(data_path)
    " NOTE: data is not found. generate data?
    call s:Message.echomsg('MoreMsg', 'Generating vital completion data... hang tight')
    return s:update_plugin_data(a:plugin_name)
  endif
  sandbox let s:data_cache[a:plugin_name] = eval(readfile(data_path, 1)[0])
  return s:data_cache[a:plugin_name]
endfunction

function! s:data_path(plugin_name) abort
  return expand(printf('~/.config/vim/vital-complete/%s.data', a:plugin_name))
endfunction

function! s:update_plugin_data(plugin_name) abort
  call s:File.mkdir_nothrow(expand('~/.config/vim/vital-complete/'), 'p')
  let data = s:generate_plugin_data(a:plugin_name)
  call writefile([string(data)], s:data_path(a:plugin_name))
  return data
endfunction

function! s:generate_plugin_data(plugin_name) abort
  let V = vital#of(a:plugin_name)
  let plugin_data = {}
  for module_name in V.search('**')
    let M = V.import(module_name)
    let plugin_data[module_name] = s:generate_module_data(M)
  endfor
  return plugin_data
endfunction

function! s:generate_module_data(Module) abort
  if empty(a:Module)
    return {}
  endif
  let sid = 0
  for Func in values(a:Module)
    let sid = s:sid_from_sfunc(Func)
    break
  endfor
  let info = filter(s:ScriptLocal.sid2sfuncs_info(sid), 'v:key =~# "^\\a"')
  return map(info, "s:Dict.pick(v:val, ['args', 'attrs'])")
endfunction

function! s:sid_from_sfunc(sfunc) abort
  return str2nr(matchstr(string(a:sfunc), 'function(''<SNR>\zs\d\+\ze_\w\+'')'))
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" __END__
" vim: expandtab softtabstop=2 shiftwidth=2 foldmethod=marker
