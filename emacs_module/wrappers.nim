# Wrapper procs for Emacs Module API, translated from the C code in
# http://phst.github.io/emacs-modules.html.

import emacs_module

type
  NonZeroExitStatus = object of Exception
  StringError = object of Exception
  InputError = object of Exception
  # UserError = object of Exception


proc clearExitStatus*(env: ptr emacs_env) =
  ## Clear non-local exit status i.e. reset it to
  ## ``emacs_funcall_exit_return``.
  env.non_local_exit_clear(env)


proc copyStrNoExitStatusAssert(env: ptr emacs_env; elispStr: emacs_value): string =
  ## Copy Emacs-Lisp string ``elispStr`` to a Nim string and return it.
  var
    l: ptrdiff_t
  # Get the length of the elisp string elispStr. It's num chars + 1
  # because it includes the null-termination too.
  discard env.copy_string_contents(env, elispStr, nil, addr l)
  if l <= 0:
    raise newException(StringError, "The length of the string passed from Emacs has to be at least 1 " &
      "(that includes the null termination), but it was " & $l)
  var
    str = newString(l)
  # *Now* copy the elisp string elispStr to Nim string str.
  discard env.copy_string_contents(env, elispStr, addr str[0], addr l)
  # Return the string without the null termination i.e. without the
  # last character.
  return str[0 ..< str.high]


proc symbolName(env: ptr emacs_env; sym: emacs_value): string =
  ## Return the name of the input Emacs-Lisp symbol
  let
    fSym = env.intern(env, "symbol-name")
  var
    listArgs: array[1, emacs_value] = [sym]
    elispStr = env.funcall(env, fSym, 1, addr listArgs[0])
  return copyStrNoExitStatusAssert(env, elispStr)


proc typeOfEmacsValue(env: ptr emacs_env; val: emacs_value): string =
  ## Return the type of the input Emacs-Lisp value as string.
  let
    typeSym: emacs_value = env.type_of(env, val)
    fSym = env.intern(env, "symbol-name")
  var
    listArgs: array[1, emacs_value] = [typeSym]
    elispStr = env.funcall(env, fSym, 1, addr listArgs[0])
  return copyStrNoExitStatusAssert(env, elispStr)


proc assertSuccessExitStatus*(env: ptr emacs_env) =
  ## Raise an exception if the non-local exit check does not return
  ## ``emacs_funcall_exit_return``.
  var
    exitSymbol, exitData: emacs_value
  let
    exitStatus: emacs_funcall_exit = env.non_local_exit_get(env,
                                                            addr exitSymbol,
                                                            addr exitData)
  # echo $exitStatus, ", ", typeOfEmacsValue(env, exitSymbol), ", ", typeOfEmacsValue(env, exitData)
  if not (exitStatus == emacs_funcall_exit_return):
    raise newException(NonZeroExitStatus, "Non-zero exit status " &
      $exitStatus &
      " (" & $ord(exitStatus) & ") detected")


# http://phst.github.io/emacs-modules.html#copy_string_contents
proc CopyStringContents*(env: ptr emacs_env; elispStr: emacs_value): string =
  ## Copy Emacs-Lisp string ``elispStr`` to a Nim string and return it.
  var
    l: ptrdiff_t
  # Get the length of the elisp string elispStr. It's num chars + 1
  # because it includes the null-termination too.
  discard env.copy_string_contents(env, elispStr, nil, addr l)
  if l <= 0:
    raise newException(StringError, "The length of the string passed from Emacs has to be at least 1 " &
      "(that includes the null termination), but it was " & $l)
  env.assertSuccessExitStatus
  var
    str = newString(l)
  # *Now* copy the elisp string elispStr to Nim string str.
  discard env.copy_string_contents(env, elispStr, addr str[0], addr l)
  env.assertSuccessExitStatus
  # Return the string without the null termination i.e. without the
  # last character.
  return str[0 ..< str.high]


# http://phst.github.io/emacs-modules.html#how-to-deal-with-nonlocal-exits-properly
proc ExtractInteger*(env: ptr emacs_env; inp: emacs_value; nimAssert = true): int =
  ## Convert Emacs-Lisp integer to an int in Nim and return it.
  if nimAssert:
    let
      inpType = typeOfEmacsValue(env, inp)
    if inpType != "integer":
      raise newException(InputError, "Input value from Emacs is of invalid type; integer was expected, but found " &
        inpType)
    else:
      result = int(env.extract_integer(env, inp))
    env.assertSuccessExitStatus
  else:
    result = int(env.extract_integer(env, inp))


# http://phst.github.io/emacs-modules.html#how-to-deal-with-nonlocal-exits-properly
proc putExit*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#how-to-deal-with-nonlocal-exits-properly
proc MakeInteger*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#make_string
proc MakeString*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#intern
proc Intern*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#make_function
# See if the defun template can add more stuff from the suggested
# defun wrapper.
# proc defun*(env: ptr emacs_env): emacs_value =
#   discard


# http://phst.github.io/emacs-modules.html#make_function
proc defunInteractive*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#make_function
proc defMacro*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#make_function
proc applyDeclaration*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#funcall
proc funcallSymbol*(env: ptr emacs_env): emacs_value =
  discard
