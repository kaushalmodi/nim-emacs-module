# Wrapper procs for Emacs Module API, translated from the C code in
# http://phst.github.io/emacs-modules.html.

from unicode import validateUtf8
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


proc copyStrNoAssert(env: ptr emacs_env; elispStr: emacs_value): string =
  ## Copy Emacs-Lisp string ``elispStr`` to a Nim string, and return it.
  var
    l: ptrdiff_t
  # Get the length of the elisp string elispStr. It's num chars + 1
  # because it includes the null-termination too.
  discard env.copy_string_contents(env, elispStr, nil, addr l)
  if l <= 0:
    return ""
  var
    str = newString(l)
  # *Now* copy the elisp string elispStr to Nim string str.
  discard env.copy_string_contents(env, elispStr, addr str[0], addr l)
  # Return the string without the null termination i.e. without the
  # last character.
  return str[0 ..< str.high]


proc symbolName(env: ptr emacs_env; sym: emacs_value): string =
  ## Return the string name for the input Emacs-Lisp symbol.
  let
    fSym = env.intern(env, "symbol-name")
  var
    listArgs: array[1, emacs_value] = [sym]
    elispStr = env.funcall(env, fSym, 1, addr listArgs[0])
  return copyStrNoAssert(env, elispStr)


proc typeOfEmacsValue(env: ptr emacs_env; val: emacs_value): string =
  ## Return the type of the input Emacs-Lisp value as string.
  let
    typeSym: emacs_value = env.type_of(env, val)
  return symbolName(env, typeSym)


proc assertSuccessExitStatus*(env: ptr emacs_env) =
  ## Raise an exception if the non-local exit check does not return
  ## ``emacs_funcall_exit_return``.
  var
    exitSymbol, exitData: emacs_value
  let
    exitStatus: emacs_funcall_exit = env.non_local_exit_get(env,
                                                            addr exitSymbol,
                                                            addr exitData)
  if not (exitStatus == emacs_funcall_exit_return):
    var
      exitSymbolStr, exitDataStr = ""
    if typeOfEmacsValue(env, exitSymbol) == "symbol":
      exitSymbolStr = "[" & symbolName(env, exitSymbol) & "]"
    if typeOfEmacsValue(env, exitData) == "symbol":
      exitDataStr = symbolName(env, exitData)
    raise newException(NonZeroExitStatus, "Non-zero exit status " &
      $exitStatus &
      " (" & $ord(exitStatus) & "): " &
      exitSymbolStr &
      exitDataStr)


# http://phst.github.io/emacs-modules.html#make_string
proc MakeString*(env: ptr emacs_env; str: string): emacs_value =
  ## Convert a Nim string to an Emacs-Lisp string, and return it.
  let
    strLen: ptrdiff_t = str.len
  if strLen > cast[ptrdiff_t](int.high):
    raise newException(OverflowError, "String size is too large")
  if str.validateUtf8 != -1:
    raise newException(StringError, "Input string is not a valid UTF-8 string")
  # If the below str variable is declared using a let instead of a
  # var, unsafeAddr has to be used in the make_string call below
  # instead of addr.
  var str = str
  result = env.make_string(env, addr str[0], strLen)
  env.assertSuccessExitStatus


# http://phst.github.io/emacs-modules.html#intern
proc Intern*(env: ptr emacs_env; symbolName: string; nimAssert = true): emacs_value =
  ## Return the Emacs-Lisp symbol for the input ``symbolName`` string.
  ##
  ## Call ``intern`` in the env object directly only if the
  ## ``symbolName`` string contains only ASCII characters
  ## (i.e. characters in the range from 1 to 127); otherwise call the
  ## ``intern`` function within Emacs via ``funcall``.
  var
    simple = true
  for c in symbolName:
    if ord(c) < 1 or ord(c) > 127:
      simple = false
      break
  if simple:
    result = env.intern(env, symbolName)
  else:
    let
      fSym = Intern(env, "intern")
      elispStr = MakeString(env, symbolName)
    var
      listArgs: array[1, emacs_value] = [elispStr]
    result = env.funcall(env, fSym, 1, addr listArgs[0])
  if nimAssert:
    env.assertSuccessExitStatus


proc symNil*(env: ptr emacs_env): emacs_value =
  ## Return Emacs-Lisp ``nil`` symbol.
  return Intern(env, "nil", nimAssert = false)


proc symT*(env: ptr emacs_env): emacs_value =
  ## Return Emacs-Lisp ``t`` symbol.
  return Intern(env, "t", nimAssert = false)


proc Funcall*(env: ptr emacs_env; fName: string): emacs_value =
  ## Return ``funcall`` of ``(fName)`` from Emacs-Lisp.
  let
    fSym = Intern(env, fName)
  result = env.funcall(env, fSym, 0, nil)
  env.assertSuccessExitStatus


# http://phst.github.io/emacs-modules.html#funcall
proc Funcall*(env: ptr emacs_env; fName: string; listArgs: openArray[emacs_value]): emacs_value =
  ## Return ``funcall`` of ``fName`` with list of arguments
  ## ``listArgs`` from Emacs-Lisp.
  let
    fSym = Intern(env, fName)
    nArgs = listArgs.len
  if nArgs > cast[ptrdiff_t](int.high):
    raise newException(OverflowError, "Too many arguments")
  result = env.funcall(env, fSym, nArgs, unsafeAddr listArgs[0])
  env.assertSuccessExitStatus


# http://phst.github.io/emacs-modules.html#copy_string_contents
proc CopyStringContents*(env: ptr emacs_env; elispStr: emacs_value): string =
  ## Copy Emacs-Lisp string ``elispStr`` to a Nim string, and return it.
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
  ## Convert Emacs-Lisp integer to an int in Nim, and return it.
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


proc MakeInteger*(env: ptr emacs_env; i: int; nimAssert = true): emacs_value =
  ## Convert a Nim int to an Emacs-Lisp integer, and return it.
  result = env.make_integer(env, cast[intmax_t](i))
  if nimAssert:
    env.assertSuccessExitStatus


proc ExtractFloat*(env: ptr emacs_env; inp: emacs_value; nimAssert = true): float =
  ## Convert Emacs-Lisp float to a float in Nim, and return it.
  if nimAssert:
    let
      inpType = typeOfEmacsValue(env, inp)
    if inpType != "float":
      raise newException(InputError, "Input value from Emacs is of invalid type; float was expected, but found " &
        inpType)
    else:
      result = float(env.extract_float(env, inp))
    env.assertSuccessExitStatus
  else:
    result = float(env.extract_float(env, inp))


proc MakeFloat*(env: ptr emacs_env; f: float; nimAssert = true): emacs_value =
  ## Convert a Nim float to an Emacs-Lisp float, and return it.
  result = env.make_float(env, cast[cdouble](f))
  if nimAssert:
    env.assertSuccessExitStatus


proc MakeBool*(env: ptr emacs_env; b: bool): emacs_value =
  ## Convert a Nim bool to an Emacs-Lisp ``t`` or ``nil``.
  if b:
    return env.symT
  else:
    return env.symNil


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
