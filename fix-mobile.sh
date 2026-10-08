#!/bin/bash
# WHMReseller: make the plugin usable on phones.
#
#  - Tables (resellers, accounts, ...) turn into stacked cards on small screens,
#    one card per row with "Label: value" lines, so nothing is cut off.
#  - The tab bar (Dash / Alpha / Master / WHM / Tools) scrolls sideways instead
#    of wrapping into several lines.
#  - The logo shrinks to fit, and edit/create dialogs use the full width.
#
# Desktop layout is unchanged (everything is inside a max-width: 767px rule).
# Safe to run more than once: it removes its own previous block first.
# Works with fix-cplimit.sh in any order.
#
# Undo:
#   cd /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
#   for f in rootmainpage alphamainpage mastermainpage; do
#     sed -i '/WHMR-MOBILE-FIX BEGIN/,/WHMR-MOBILE-FIX END/d' $f
#   done

set -e
DIR=/usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
PAGES="rootmainpage alphamainpage mastermainpage"

BLOCK=$(mktemp)
trap 'rm -f "$BLOCK"' EXIT

# The block must contain no "$" characters, so the plugin's own
# $PLACEHOLDER replacement leaves it untouched.
cat > "$BLOCK" <<'EOF'
<!-- WHMR-MOBILE-FIX BEGIN -->
<style>
@media (max-width: 767.98px) {
  /* logo and images fit the screen */
  img, svg.logo { max-width: 100%; height: auto; }

  /* tab bar: one line, swipe sideways */
  .nav-tabs { flex-wrap: nowrap; overflow-x: auto; overflow-y: hidden;
              -webkit-overflow-scrolling: touch; scrollbar-width: none; }
  .nav-tabs::-webkit-scrollbar { display: none; }
  .nav-tabs .nav-item, .nav-tabs .nav-link { white-space: nowrap; flex: 0 0 auto; }

  /* tables become cards */
  table.whmr-cards, table.whmr-cards tbody,
  table.whmr-cards tr, table.whmr-cards td { display: block; width: 100%; }
  table.whmr-cards thead { display: none; }
  table.whmr-cards tr {
    margin: 0 0 12px; padding: 4px 12px;
    border: 1px solid #dee2e6; border-radius: 8px;
    background: #fff !important; box-shadow: 0 1px 2px rgba(0,0,0,.04);
  }
  table.whmr-cards td {
    padding: 8px 0 !important; border: 0 !important;
    border-bottom: 1px solid #f1f3f5 !important;
    text-align: right; word-break: break-word; font-size: 14px !important;
    line-height: 1.6;
  }
  table.whmr-cards td::after { content: ""; display: table; clear: both; }
  table.whmr-cards td:last-child { border-bottom: 0 !important; }
  table.whmr-cards td::before {
    content: attr(data-label); float: left; margin-right: 12px;
    font-weight: 600; color: #6c757d; text-align: left;
  }
  table.whmr-cards td .btn-group { vertical-align: middle; }
  table.whmr-cards td.whmr-full { display: block; text-align: left; }
  table.whmr-cards td.whmr-full::before { content: none; }
  table.whmr-cards td:first-child { font-weight: 600; font-size: 15px !important; }
  table.whmr-cards tr.table-danger, table.whmr-cards tr.text-danger {
    border-color: #f5c6cb;
  }

  /* page columns (Dash stats, Tools panels): stack instead of squeezing */
  .row > [class*="col-"] { flex: 0 0 100%; max-width: 100%; }
  .row > [class*="col-"] + [class*="col-"] { margin-top: 12px; }
  .form-group.row > [class*="col-"] + [class*="col-"] { margin-top: 0; }
  .list-group-item { word-break: normal; overflow-wrap: anywhere; }
  .nav-pills { flex-wrap: wrap; }
  .card { max-width: 100% !important; }
  .highcharts-container, .highcharts-root { max-width: 100%; }

  /* dialogs: drop the big icon column, form uses the full width */
  .modal-dialog { margin: 8px; }
  .modal-body .row > .col-4 { display: none; }
  .modal-body .row > .col-8 { margin-top: 0; }
}
</style>
<script>
(function () {
  function labelTables() {
    document.querySelectorAll('table').forEach(function (t) {
      var ths = t.querySelectorAll('thead th');
      if (!ths.length) return;
      var names = Array.prototype.map.call(ths, function (th) { return th.textContent.trim(); });
      if (!t.classList.contains('whmr-cards')) t.classList.add('whmr-cards');
      t.querySelectorAll('tbody > tr').forEach(function (tr) {
        Array.prototype.forEach.call(tr.children, function (td, i) {
          if (td.hasAttribute('data-label')) return;
          if (td.colSpan > 1 || names[i] == null) {
            td.setAttribute('data-label', '');
            td.classList.add('whmr-full');
          } else {
            td.setAttribute('data-label', names[i]);
          }
        });
      });
    });
  }
  labelTables();
  document.addEventListener('DOMContentLoaded', labelTables);
  // charts are drawn at the old column width; ask them to redraw once the
  // stacked layout is in place
  window.addEventListener('load', function () {
    setTimeout(function () { window.dispatchEvent(new Event('resize')); }, 300);
  });
  new MutationObserver(labelTables).observe(document.documentElement, { childList: true, subtree: true });
})();
</script>
<!-- WHMR-MOBILE-FIX END -->
EOF

for p in $PAGES; do
  f="$DIR/$p"
  [ -f "$f" ] || { echo "$p: not found, skipped"; continue; }
  [ -f "$f.orig" ] || cp -a "$f" "$f.orig"
  sed -i '/WHMR-MOBILE-FIX BEGIN/,/WHMR-MOBILE-FIX END/d' "$f"
  cat "$BLOCK" >> "$f"
  echo "$p: patched"
done

echo
echo "Done. Open WHMReseller on your phone (or narrow the browser) and reload."
