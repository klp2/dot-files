# ~/.profile: read by login shells other than bash, which reads
# ~/.bash_profile instead. Kept POSIX: only hand off to ~/.bashrc under bash.
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
