#!/bin/bash
# Show the real cPanel account limit WHM enforces for every reseller.
# Usage: bash check-limits.sh

for u in $(cut -d: -f1 /var/cpanel/resellers); do
  out=$(whmapi1 acctcounts user="$u")
  a=$(echo "$out" | awk '/active:/{print $2}')
  l=$(echo "$out" | awk '/limit:/{print $2}' | tr -d "'")
  flag=""
  if [ -n "$l" ] && [ "$l" != "unlimited" ] && [ "$a" -ge "$l" ] 2>/dev/null; then
    flag="  <-- at/over limit"
  fi
  printf "%-20s active=%-5s limit=%s%s\n" "$u" "$a" "${l:-NONE (unlimited)}" "$flag"
done
