# First-terminal welcome for try-scoot (MIT). Sourced once per terminal
# session from ~/.bashrc (guarded there by TRY_SCOOT_WELCOMED); set
# TRY_SCOOT_NO_WELCOME=1 to turn it off. Short, fast (builtins only: the
# shell starts no processes for this), no ASCII-art wall. Every line fits
# 60 columns; the rerun command wraps with a trailing backslash so the
# image URL stays whole on its own line.
#
# Keys are this image's real binds (every Alt chord mirrored on Super for
# browsers that grab Alt): Return opens a terminal, d the launcher,
# q closes, h/l moves focus between columns.
printf '%s\n' \
  'try-scoot: ginger-night scoot in your browser.' \
  'Super+Return terminal, Super+d launcher' \
  'Super+q close, Super+h/l columns (Alt mirrors all)' \
  'Columns scroll, no GPU, agent-drivable via scoot msg.' \
  'Rerun: docker run --rm -p 127.0.0.1:6080:6080 \' \
  '  ghcr.io/scoot-sh/try-scoot'
