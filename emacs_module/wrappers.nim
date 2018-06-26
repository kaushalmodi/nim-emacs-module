# Wrapper procs for Emacs Module API, translated from the C code in
# http://phst.github.io/emacs-modules.html.

from unicode import validateUtf8
import emacs_module


# Forward declarations
proc strEmacsValue(env: ptr emacs_env; x: emacs_value): string
proc symNil*(env: ptr emacs_env): emacs_value
proc MakeList*(env: ptr emacs_env; listArray: openArray[emacs_value]): emacs_value


proc clearExitStatus*(env: ptr emacs_env) =
  ## Clear non-local exit status i.e. reset it to
  ## ``emacs_funcall_exit_return``.
  env.non_local_exit_clear(env)


proc exitSignalError*(env: ptr emacs_env; errorType, errorMsg: string) =
  ## Send ``error`` signal to Emacs.
  var
    cStr: cstring = errorMsg
    elispStr: emacs_value = env.make_string(env, addr cStr[0], cStr.len)
  # echo " >> ", errorType, ": ", cStr
  # If a non-local exit signal is pending, env.non_local_exit_signal
  # does nothing. So clear any pending signal first.
  clearExitStatus(env)
  env.non_local_exit_signal(env, env.intern(env, errorType), MakeList(env, [elispStr]))
proc exitSignalError*(env: ptr emacs_env; errorType: string; errorVal: emacs_value) =
  ## Send ``error`` signal to Emacs.
  clearExitStatus(env)
  env.non_local_exit_signal(env, env.intern(env, errorType), errorVal)


proc isSuccessExitStatus*(env: ptr emacs_env): bool =
  ## Return ``true`` if the current exit status is success.
  let exitStatus: emacs_funcall_exit = env.non_local_exit_check(env)
  return (exitStatus == emacs_funcall_exit_return)


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


proc symbolName*(env: ptr emacs_env; sym: emacs_value): string =
  ## Return the string name for the input Emacs-Lisp symbol.
  let
    fSym = env.intern(env, "symbol-name")
  var
    listArgs: array[1, emacs_value] = [sym]
    elispStr = env.funcall(env, fSym, 1, addr listArgs[0])
  if not isSuccessExitStatus(env):
    return ""
  return copyStrNoAssert(env, elispStr)


proc typeOfEmacsValue*(env: ptr emacs_env; val: emacs_value): string =
  ## Return the type of the input Emacs-Lisp value as string.
  let
    typeSym: emacs_value = env.type_of(env, val)
  echo strEmacsValue(env, val)
  return symbolName(env, typeSym)


proc typeCheck*(env: ptr emacs_env; val: emacs_value; expectedType: string): bool =
  ## Return ``false`` and signal error if the type of ``val`` does not
  ## match ``expectedType``.
  let
    argType = typeOfEmacsValue(env, val)
  result = (argType == expectedType)
  if not result:
    exitSignalError(env, "wrong-type-argument",
                    "Input is of type `" & argType & "' instead of `" &
                      expectedType & "'")


# http://phst.github.io/emacs-modules.html#make_string
proc MakeString*(env: ptr emacs_env; str: string): emacs_value =
  ## Convert a Nim string to an Emacs-Lisp string, and return it.
  # If the below cStr variable is declared using a let instead of a
  # var, unsafeAddr has to be used in the make_string call below
  # instead of addr.
  # Making this a cstring is necessary as the minimum required
  # string length is 1 (when the string is empty, the appended
  # null-termination in cstring makes the string length 1).
  var
    cStr = str.cstring
  let
    cStrLen: ptrdiff_t = cStr.len
  if cStrLen > cast[ptrdiff_t](int.high):
    exitSignalError(env, "overflow-error", "String size is too large")
    return symNil(env)
  if str.validateUtf8 != -1:
    exitSignalError(env, "string-error", "Input string is not a valid UTF-8 string")
    return symNil(env)
  result = env.make_string(env, addr cStr[0], cStrLen)
  if not isSuccessExitStatus(env):
    return symNil(env)


# http://phst.github.io/emacs-modules.html#intern
proc Intern*(env: ptr emacs_env; symbolName: string): emacs_value =
  ## Return the Emacs-Lisp symbol for the input ``symbolName`` string.
  ##
  ## Call ``intern`` in the env object directly only if the
  ## ``symbolName`` string contains only ASCII characters
  ## (i.e. characters in the range from 1 to 127); otherwise call the
  ## ``intern`` function within Emacs via ``funcall``.
  var
    simple = true
  for c in symbolName:
    if c notin {'\1' .. '\127'}:
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
  # Do NOT check for isSuccessExitStatus here.

proc toEmacsValue*(env: ptr emacs_env; inp: string): emacs_value =
  ## Convert a Nim string to an Emacs-Lisp string, and return it.  If
  ## the string begins with a single-quote, return its interned value
  ## instead.
  let
    hasQuotePrefix = (inp.len >= 2) and (inp[0] == '\39')
  if hasQuotePrefix:
    return Intern(env, inp[1 .. inp.high])
  else:
    return MakeString(env, inp)


proc symNil*(env: ptr emacs_env): emacs_value =
  ## Return Emacs-Lisp ``nil`` symbol.
  return Intern(env, "nil")


proc symT*(env: ptr emacs_env): emacs_value =
  ## Return Emacs-Lisp ``t`` symbol.
  return Intern(env, "t")


proc Funcall*(env: ptr emacs_env; fName: string): emacs_value =
  ## Return ``funcall`` of ``(fName)`` from Emacs-Lisp.
  let
    fSym = Intern(env, fName)
  result = env.funcall(env, fSym, 0, nil)
  if not isSuccessExitStatus(env):
    return symNil(env)


# http://phst.github.io/emacs-modules.html#funcall
proc Funcall*(env: ptr emacs_env; fName: string; listArgs: openArray[emacs_value]): emacs_value =
  ## Return ``funcall`` of ``fName`` with list of arguments
  ## ``listArgs`` from Emacs-Lisp.
  let
    fSym = Intern(env, fName)
    nArgs = listArgs.len
  if nArgs > cast[ptrdiff_t](int.high):
    exitSignalError(env, "overflow-error", "Too many arguments")
    return symNil(env)
  result = env.funcall(env, fSym, nArgs, unsafeAddr listArgs[0])
  if not isSuccessExitStatus(env):
    return symNil(env)


# http://phst.github.io/emacs-modules.html#copy_string_contents
proc CopyStringContents*(env: ptr emacs_env; elispStr: emacs_value): string =
  ## Copy Emacs-Lisp string ``elispStr`` to a Nim string, and return it.
  if not typeCheck(env, elispStr, "string"):
    return ""
  var
    l: ptrdiff_t
  # Get the length of the elisp string elispStr. It's num chars + 1
  # because it includes the null-termination too.
  discard env.copy_string_contents(env, elispStr, nil, addr l)
  if not isSuccessExitStatus(env):
    return ""
  if l <= 0:
    exitSignalError(env, "string-error",
                    "The length of the string " &
                      "passed from Emacs has to be at least 1 " &
                      "(that includes the null termination), but " &
                      "it was " & $l)
    return ""
  var
    str = newString(l)
  # *Now* copy the elisp string elispStr to Nim string str.
  discard env.copy_string_contents(env, elispStr, addr str[0], addr l)
  if not isSuccessExitStatus(env):
    return ""
  # Return the string without the null termination i.e. without the
  # last character.
  return str[0 ..< str.high]


# http://phst.github.io/emacs-modules.html#how-to-deal-with-nonlocal-exits-properly
proc ExtractInteger*(env: ptr emacs_env; inp: emacs_value; internalCall = false): int =
  ## Convert Emacs-Lisp integer to an int in Nim, and return it.
  if not isSuccessExitStatus(env):
    return
  if not internalCall: # Break recursive call when called from strEmacsValue
    if not typeCheck(env, inp, "integer"):
      return
  result = int(env.extract_integer(env, inp))
  if not isSuccessExitStatus(env):
    return


proc MakeInteger*(env: ptr emacs_env; i: int): emacs_value =
  ## Convert a Nim int to an Emacs-Lisp integer, and return it.
  if not isSuccessExitStatus(env):
    return symNil(env)
  result = env.make_integer(env, cast[intmax_t](i))
  if not isSuccessExitStatus(env):
    return symNil(env)
proc toEmacsValue*(env: ptr emacs_env; inp: int): emacs_value =
  ## Convert a Nim int to an Emacs-Lisp integer, and return it.
  return MakeInteger(env, inp)


proc ExtractFloat*(env: ptr emacs_env; inp: emacs_value; internalCall = false): float =
  ## Convert Emacs-Lisp float to a float in Nim, and return it.
  if not isSuccessExitStatus(env):
    return
  if not internalCall: # Break recursive call when called from strEmacsValue
    if not typeCheck(env, inp, "float"):
      return
  result = float(env.extract_float(env, inp))
  if not isSuccessExitStatus(env):
    return


proc MakeFloat*(env: ptr emacs_env; f: float): emacs_value =
  ## Convert a Nim float to an Emacs-Lisp float, and return it.
  if not isSuccessExitStatus(env):
    return symNil(env)
  result = env.make_float(env, cast[cdouble](f))
  if not isSuccessExitStatus(env):
    return symNil(env)
proc toEmacsValue*(env: ptr emacs_env; inp: float): emacs_value =
  ## Convert a Nim float to an Emacs-Lisp float, and return it.
  MakeFloat(env, inp)


proc MakeBool*(env: ptr emacs_env; b: bool): emacs_value =
  ## Convert a Nim bool to an Emacs-Lisp ``t`` or ``nil``.
  if b:
    return env.symT
  else:
    return env.symNil
proc toEmacsValue*(env: ptr emacs_env; inp: bool): emacs_value =
  ## Convert a Nim bool to an Emacs-Lisp ``t`` or ``nil``.
  return MakeBool(env, inp)


proc MakeList*(env: ptr emacs_env; listArray: openArray[emacs_value]): emacs_value =
  ## Return an Emacs-Lisp ``list``.
  Funcall(env, "list", listArray)


proc strEmacsValue(env: ptr emacs_env; x: emacs_value): string =
  ## Get stringified form of ``emacs_value``.
  let t = typeOfEmacsValue(env, x)
  case t
  of "string":
    copyStrNoAssert(env, x)
  of "integer":
    $ExtractInteger(env, x, internalCall = true)
  of "float":
    $ExtractFloat(env, x, internalCall = true)
  of "symbol":
    symbolName(env, x)
  else:
    "$ unsupported for " & t


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
