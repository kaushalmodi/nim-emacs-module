import strutils as su
import emacs_module

type Emacs* = object
  functions*: string

proc storeFunction*(self: var Emacs, fn: string, max_args: int) =
  let emacs_func = su.replace(fn.substr(1, high(fn)), "_", "-")
  self.functions.add(
    su.format("""DEFUN ("$1", $2, $3, $4, NULL, NULL);
              emacs_func, fn, max_args, max_args)
  )

# my memo:
#   immediate, and dirty: http://forum.nim-lang.org/t/1100
#   expr, stmt, typed, and untyped: http://forum.nim-lang.org/t/2025
template defun*(self, function_name, max_args, body: untyped)
    {.dirty, immediate.} = ## \
  ## emacs_func(env: ptr emacs_env, nargs: ptrdiff_t,
  ## args: ptr array[0..max_args, emacs_value], data: pointer):
  ## emacs_value {.exportc.}
  static:
    self.storeFunction(astToStr(function_name), max_args)
  proc function_name*(env: ptr emacs_env, nargs: ptrdiff_t,
                      args: ptr array[0..max_args, emacs_value],
                      data: pointer): emacs_value {.exportc.}=
    body


template emitBody(body: typed): typed =
  {.emit: body.}

template provide* (self, package_name: typed) =
  doAssert(package_name is string)
  emitBody(su.format("""
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
""", self.functions, package_name))