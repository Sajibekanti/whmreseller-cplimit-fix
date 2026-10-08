#!/bin/bash
# WHMReseller: fix "CPs: X / ∞" display on the WHM Resellers tab.
# The real limit is already enforced by WHM; this only makes the plugin SHOW it.
# Reads the live limit/used count from WHM's own API (acctcounts) in the browser.
# Safe to run more than once. Re-run after any plugin update.
#
# Undo:
#   cd /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
#   cp -a whmentry.orig whmentry && cp -a rootmainpage.orig rootmainpage

set -e
DIR=/usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
ENTRY="$DIR/whmentry"
MAIN="$DIR/rootmainpage"
MARK="WHMR-CPLIMIT-FIX"

# Keep one pristine copy of each original template
[ -f "$ENTRY.orig" ] || cp -a "$ENTRY" "$ENTRY.orig"
[ -f "$MAIN.orig" ]  || cp -a "$MAIN"  "$MAIN.orig"

# 1) Wrap used/limit in tagged spans so the script can find them per user
if grep -q 'whmr-cplimit' "$ENTRY"; then
  echo "whmentry: already patched"
else
  sed -i 's#\$CPUSED / \$CPLIMIT#<span class="whmr-cpused" data-user="$USERNAME">$CPUSED</span> / <span class="whmr-cplimit" data-user="$USERNAME">$CPLIMIT</span>#' "$ENTRY"
  grep -q 'whmr-cplimit' "$ENTRY" && echo "whmentry: patched" || { echo "whmentry: pattern not found, nothing changed"; exit 1; }
fi

# 2) Add the script to the root main page (no "$" signs inside, so the
#    plugin's own $PLACEHOLDER replacement leaves it alone)
if grep -q "$MARK" "$MAIN"; then
  echo "rootmainpage: already patched"
else
  cat >> "$MAIN" <<'EOF'
<!-- WHMR-CPLIMIT-FIX -->
<script>
(function () {
  var m = location.pathname.match(/\/cpsess\d+/);
  if (!m) return;
  var base = m[0] + '/json-api/acctcounts?api.version=1&user=';
  var INF = '\u221e';

  function run() {
    document.querySelectorAll('.whmr-cplimit:not([data-done])').forEach(function (el) {
      el.setAttribute('data-done', '1');
      var user = el.getAttribute('data-user');
      fetch(base + encodeURIComponent(user), { credentials: 'same-origin' })
        .then(function (r) { return r.json(); })
        .then(function (j) {
          var r = j && j.data && j.data.reseller;
          if (!r) return;
          var lim = (r.limit === '' || r.limit == null || r.limit === 'unlimited') ? INF : String(r.limit);
          el.textContent = lim;
          var used = document.querySelector('.whmr-cpused[data-user="' + user + '"]');
          if (used && r.active != null) used.textContent = r.active;
          if (lim !== INF && Number(r.active) >= Number(lim)) {
            el.parentNode.style.color = '#dc3545';
            el.parentNode.title = 'At or over cPanel account limit';
          }
        })
        .catch(function () { /* leave plugin value as-is */ });
    });
  }

  run();
  document.addEventListener('DOMContentLoaded', run);
  new MutationObserver(run).observe(document.documentElement, { childList: true, subtree: true });
})();
</script>
EOF
  echo "rootmainpage: patched"
fi

echo "Done. Reload WHM > Plugins > WHMReseller > WHM Resellers."
