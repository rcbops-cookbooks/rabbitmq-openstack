#!/usr/bin/env bash

# Max seconds to wait for VIP to show up
_max=5

# Helper functions
_log() { if [[ -n "$1" ]]; then logger -t update_route "$2" "$1"; fi; }

_exit() {
  if [[ -n "$1" ]]; then
    if [[ $2 ]]; then
      _log "$1" "-s"
    else
      _log "$1"
    fi
  fi
  exit 1
}

_errexit() { _exit "$1" 1; }

_help() { _errexit "Error updating route. Usage: (add | del) vip"; }

# Grab interface for local route matching $vip
_iface() { echo "$(ip r sh table local $1 2>/dev/null | cut -d' ' -f4)"; }

# Grab args
action=$1; vip=$2

# Check args
if [[ $# -lt 2 ]] || [[ -z $action ]] || [[ -z $vip ]]; then _help; fi

# Try to snag VIP interface
iface=$(_iface $vip); count=0

# If VIP route isn't in table pause and try some more
while [[ -z $iface ]] && [[ $count -le $_max ]]; do
  sleep 1 # Wait for VIP to be available
  iface=$(_iface $vip) # Check again
  count=$((count + 1)) # Shep++
done

# Still didn't find it?
if [[ -z $iface ]]; then _errexit "Invalid VIP $vip! VIP must exist on an interface."; fi

# Grab primary IP on interface
src=$(ip -o -4 a sh $iface primary | sed -nr '1 s/^.*inet ([^/]*).*$/\1/p')

# Check it
if [[ -z $src ]]; then _errexit "No IP found on $iface. Expected at least $vip."; fi
if [[ $src == $vip ]]; then _errexit "Primary IP $src on $iface is VIP. A non-VIP primary IP must exist."; fi

# Do the things
case $action in
  "add")
    _log "Merging local route for $vip with source $src."
    ip r r table local local $vip dev $iface src $src # Replace
    ;;
  "del")
    _log "Deleting local route for $vip with source $src."
    ip r d table local local $vip dev $iface src $src # Delete
    ;;
  *)
    _help
esac

exit 0 # Success!
