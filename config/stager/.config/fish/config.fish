
# This is usually set by /etc/profile,
# but FiSH Shell doesn't not handle that file.
# From: https://forum.voidlinux.eu/t/solved-xbps-query-suddenly-requires-root-permission-to-query-a-repo/1665/10
if status --is-login
  umask 022
end

set -x IS_DEV "yes"
set -x IS_DEVELOPMENT "yes"

if  status --is-interactive ; and set -q os_name
  switch $os_name
    case rolling_void
      abbr --add pi "sudo xbps-install -S"
      abbr --add pq "xbps-query -Rs"
      abbr --add pr "sudo xbps-remove -R"
  end
end # if set -q os_name

set PATH $PATH "$HOME/bin"

