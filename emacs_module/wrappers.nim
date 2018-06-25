# Wrapper procs for Emacs Module API, translated from the C code in
# http://phst.github.io/emacs-modules.html.

import emacs_module

type
  NonZeroExitStatus = object of Exception
  StringError = object of Exception
  # UserError = object of Exception

proc assertSuccessExitStatus*(env: ptr emacs_env) =
  ## Raise an exception if the non-local exit check does not return
  ## ``emacs_funcall_exit_return``.
  let exitStatus: emacs_funcall_exit = env.non_local_exit_check(env)
  if not (exitStatus == emacs_funcall_exit_return):
    raise newException(NonZeroExitStatus, "Non-zero exit status " & $exitStatus & " (" & $ord(exitStatus) & ") detected")

# http://phst.github.io/emacs-modules.html#copy_string_contents
proc copyStringContents*(env: ptr emacs_env; elispStr: emacs_value): string =
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
proc extractInteger*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#how-to-deal-with-nonlocal-exits-properly
proc putExit*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#how-to-deal-with-nonlocal-exits-properly
proc makeInteger*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#make_string
proc makeString*(env: ptr emacs_env): emacs_value =
  discard


# http://phst.github.io/emacs-modules.html#intern
proc intern*(env: ptr emacs_env): emacs_value =
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
