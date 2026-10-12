# First-terminal welcome for try-scoot (MIT). Sourced once per terminal
# session from ~/.bashrc (guarded there by TRY_SCOOT_WELCOMED); set
# TRY_SCOOT_NO_WELCOME=1 to turn it off. Short, fast (builtins only: the
# shell starts no processes for this), no ASCII-art wall.
#
# Keys are this image's real binds (scoot defaults, with every Alt chord
# mirrored on Super for browsers that grab Alt): Super+Return opens a
# terminal, Super+d the launcher, Super+q closes, Super+h/l moves focus.
printf '%s\n' \
  'Welcome to try-scoot: scoot ginger-night in your browser.' \
  'Keys: Super+Return terminal - Super+d launcher' \
  '      Super+q close - Super+h/l columns (Alt mirrors each)' \
  'Rerun: docker run --rm -p 127.0.0.1:6080:6080 ghcr.io/scoot-sh/try-scoot'
