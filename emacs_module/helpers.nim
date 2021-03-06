import strformat
from strutils import replace, `%`

# `plugin_is_GPL_compatible` indicates that its code is released under
# the GPL or compatible license.
{.emit:"int plugin_is_GPL_compatible;".}
# Emacs will refuse to load modules that don't export such a symbol
# with an error: "Module is not GPL compatible".

type Emacs* = object
  functions*: string
  libName*: string


proc pushFunction*(self: var Emacs, fn: string, max_args: int) =
  ## Push function name ``fn`` to ``functions`` object.
  ## This variable is used later by ``provide`` proc.
  let
    emacs_func = replace(self.libName & "-" & fn, "_", "-")
    nim_func = "nimEmacs_" & self.libName & "_" & fn
    documentation = "NULL"
    dataPtr = "NULL"

  self.functions.add(&"""DEFUN ("{emacs_func}", {nim_func}, {max_args}, {max_args}, {documentation}, {dataPtr});
""")


template defun*(self: Emacs; fsym: untyped; max_args: int; body: untyped) {.dirty.} =
  ## emacs_func(env: ptr emacs_env, nargs: ptrdiff_t,
  ## args: ptr array[0..max_args, emacs_value], data: pointer):
  ## emacs_value {.exportc.}
  ## The `fsym` is registered as the name in emacs and also
  ## be registered in Nim with nimEmacs prefix.
  ## If you include "_" in the function name, it will be converted "-"
  ## in Emacs.
  static:
    self.pushFunction(astToStr(fsym), max_args)

  proc `fsym`*(env: ptr emacs_env, nargs: ptrdiff_t,
               args: ptr array[max_args, emacs_value],
               data: pointer): emacs_value {.exportc,extern: "nimEmacs_" & self.libName & "_$1".} =
    body


proc provideString*(self: Emacs): string =
  """
/* Lisp utilities for easier readability (simple wrappers).  */

/* Provide FEATURE to Emacs.  */
static void
provide (emacs_env *env, const char *feature)
{
  emacs_value Qfeat = env->intern (env, feature);
  emacs_value Qprovide = env->intern (env, "provide");
  emacs_value args[] = { Qfeat };

  env->funcall (env, Qprovide, 1, args);
}

/* Bind NAME to FUN.  */
static void
bind_function (emacs_env *env, const char *name, emacs_value Sfun)
{
  emacs_value Qfset = env->intern (env, "fset");
  emacs_value Qsym = env->intern (env, name);
  emacs_value args[] = { Qsym, Sfun };

  env->funcall (env, Qfset, 2, args);
}

/* Module init function.  */
int
emacs_module_init (struct emacs_runtime *ert)
{
  emacs_env *env = ert->get_environment (ert);
  NimMain(); // <- Nim executes this in `main` function
#define DEFUN(lsym, csym, amin, amax, doc, data) \
  bind_function (env, lsym, \
     env->make_function (env, amin, amax, csym, doc, data))
  $1

#undef DEFUN

  provide (env, "$2");
  return 0;

}
""" % [self.functions, self.libName]


template provide*(self: Emacs) {.dirty.} =
  const temp = `self`.provideString()
  {.emit: temp.}


template init*(sym: untyped, libNameCustom = ""): untyped {.dirty.} =
  from os import splitFile

  var `sym` {.compileTime.} = Emacs()

  static:
    `sym`.functions = ""
    when libNameCustom == "":
      let info = instantiationInfo()
      # If the file name is foo.nim, set the libary name to foo.
      `sym`.libName = splitFile(info.filename).name
    else:
      `sym`.libName = libNameCustom
