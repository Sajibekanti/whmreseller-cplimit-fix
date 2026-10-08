#!/bin/bash
# WHMReseller: fix the cPanel account limit showing as "unlimited" / "∞".
#
#  1. WHM Resellers list : "CPs: X / ∞"  -> real limit from WHM, red if at/over limit
#  2. Edit WHM form      : "CPanel Limit: unlimited" -> pre-filled with real limit
#  3. Save guard         : warns before saving a WHM reseller with an empty or
#                          "unlimited" CPanel Limit (which would remove the limit)
#
# The real limit lives in WHM (whmapi1 acctcounts). The page reads it from WHM's
# own JSON API using the logged-in root session. No credentials are stored.
#
# Safe to run more than once: each run restores the original templates from
# *.orig and re-applies the patch. Re-run after any plugin update.
#
# Undo:
#   cd /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
#   for f in whmentry editwhm rootmainpage; do cp -a $f.orig $f; done

set -e
DIR=/usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
ENTRY="$DIR/whmentry"
EDIT="$DIR/editwhm"
MAIN="$DIR/rootmainpage"

for f in "$ENTRY" "$EDIT" "$MAIN"; do
  [ -f "$f" ] || { echo "Missing $f - is WHMReseller installed?"; exit 1; }
  if [ -f "$f.orig" ]; then
    cp -a "$f.orig" "$f"          # start from a clean original every run
  else
    cp -a "$f" "$f.orig"          # first run: keep the original
  fi
done

# 1) List row: tag used/limit with the reseller's username
sed -i 's#\$CPUSED / \$CPLIMIT#<span class="whmr-cpused" data-user="$USERNAME">$CPUSED</span> / <span class="whmr-cplimit" data-user="$USERNAME">$CPLIMIT</span>#' "$ENTRY"
grep -q 'whmr-cplimit' "$ENTRY" && echo "whmentry:     patched" || { echo "whmentry: pattern not found"; exit 1; }

# 2) Edit form: tag the CPanel Limit box with the reseller's username
sed -i 's#id="dcplimit" value="\$CPLIMIT"#id="dcplimit" value="$CPLIMIT" data-whmr-user="$USERNAME"#' "$EDIT"
grep -q 'data-whmr-user' "$EDIT" && echo "editwhm:      patched" || { echo "editwhm: pattern not found"; exit 1; }

# 3) Script for the root page. It must contain no "$" characters, so the
#    plugin's own $PLACEHOLDER replacement leaves it untouched.
cat >> "$MAIN" <<'EOF'
<!-- WHMR-CPLIMIT-FIX v2 -->
<script>
(function () {
  var m = location.pathname.match(/\/cpsess\d+/);
  if (!m) return;
  var API = m[0] + '/json-api/acctcounts?api.version=1&user=';
  var INF = '\u221e';

  function isUnlimited(v) {
    return v === '' || v == null || String(v).toLowerCase() === 'unlimited';
  }
  function isPositiveInt(v) {
    var n = parseInt(v, 10);
    return String(n) === String(v).trim() && n > 0;
  }
  function getCounts(user) {
    return fetch(API + encodeURIComponent(user), { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (j) { return (j && j.data && j.data.reseller) || null; });
  }

  // 1) WHM Resellers list
  function fixList() {
    document.querySelectorAll('.whmr-cplimit:not([data-done])').forEach(function (el) {
      el.setAttribute('data-done', '1');
      var user = el.getAttribute('data-user');
      getCounts(user).then(function (r) {
        if (!r) return;
        var lim = isUnlimited(r.limit) ? INF : String(r.limit);
        el.textContent = lim;
        var used = document.querySelector('.whmr-cpused[data-user="' + user + '"]');
        if (used && r.active != null) used.textContent = r.active;
        if (lim !== INF && Number(r.active) >= Number(lim)) {
          el.parentNode.style.color = '#dc3545';
          el.parentNode.title = 'At or over cPanel account limit';
        }
      }).catch(function () {});
    });
  }

  // 2) Edit WHM form
  function fixEditForm() {
    var el = document.querySelector('#dcplimit[data-whmr-user]:not([data-done])');
    if (!el) return;
    el.setAttribute('data-done', '1');
    getCounts(el.getAttribute('data-whmr-user')).then(function (r) {
      if (!r || isUnlimited(r.limit)) return;
      // only replace if the user has not typed something else meanwhile
      if (isUnlimited(el.value.trim())) el.value = String(r.limit);
    }).catch(function () {});
  }

  function run() { fixList(); fixEditForm(); }
  run();
  document.addEventListener('DOMContentLoaded', run);
  new MutationObserver(run).observe(document.documentElement, { childList: true, subtree: true });

  // 3) Save guard (capture phase, runs before the plugin's own click handler)
  var GUARDED = ['editwhm', 'createwhm', 'upgradewhm', 'downgradewhm'];
  document.addEventListener('click', function (e) {
    var btn = e.target && e.target.closest ? e.target.closest('#msubmit') : null;
    if (!btn || GUARDED.indexOf(btn.getAttribute('data-type')) === -1) return;
    var f = document.getElementById('dcplimit');
    if (!f) return;
    var v = f.value.trim();
    if (isPositiveInt(v)) return;
    var ok = confirm('CPanel Limit is "' + (v || 'empty') + '".\n\n' +
      'Saving will give this reseller UNLIMITED cPanel accounts.\n\n' +
      'OK = save anyway\nCancel = go back and enter a number');
    if (!ok) {
      e.preventDefault();
      e.stopImmediatePropagation();
      f.focus();
      f.select();
    }
  }, true);
})();
</script>
EOF
echo "rootmainpage: patched"
echo
echo "Done. Reload WHM > Plugins > WHMReseller (Ctrl+F5) and open a reseller's Edit form."
