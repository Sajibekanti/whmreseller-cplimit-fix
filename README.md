# WHMReseller CP Limit Display Fix

A small patch for the **WHMReseller (v5)** cPanel/WHM plugin. On the **WHM Resellers** tab, the plugin shows every reseller's cPanel account limit as unlimited:

```
CPs: 4 / ∞
```

The plugin is no longer maintained, so this patch fixes the display locally.

## The problem

The plugin makes it look as though every reseller can create unlimited cPanel accounts.

## What is actually happening

This is a **display bug only**. The limits are set and enforced correctly:

- Each reseller package stores its limit in the plugin's package extension field `whmrcplimit`, for example `whmrcplimit=20` in `/var/cpanel/packages/<PACKAGE>`.
- The plugin passes that value to WHM through `setresellerlimits` (`enable_account_limit`, `account_limit`).
- `whmapi1 acctcounts user=<reseller>` returns the correct limit, and WHM blocks account creation once a reseller reaches it.

The plugin's compiled binary (`subreseller.cgi`) never fills the `$CPLIMIT` placeholder for WHM-type resellers. It has no cache file for that value, so the template falls back to `∞`.

### Why this matters: the Edit form can remove limits

The **Edit WHM** form has the same bug. Its **CPanel Limit** field loads as `unlimited`. When you save the form, for example to change only the disk limit, the plugin sends that value back to WHM, and the reseller's real account limit is likely **removed**. A display bug can therefore become a real unlimited reseller.

## How the fix works

The binary can't be edited, but it reads plain-text templates. `fix-cplimit.sh` patches three of them:

1. **`templates/whmentry`** (list row): wraps the `$CPUSED / $CPLIMIT` cell in tagged `<span>` elements that carry the reseller's username.
2. **`templates/editwhm`** (edit form): tags the CPanel Limit input with the reseller's username.
3. **`templates/rootmainpage`**: appends a small script that calls WHM's own JSON API (`acctcounts`) and:
   - shows the real account limit and active count in the list, in **red** when a reseller is at or over its limit
   - **pre-fills the Edit form's CPanel Limit** with the real limit instead of `unlimited`
   - **warns before saving** a reseller (edit, create, upgrade or downgrade) when CPanel Limit is empty or `unlimited`, so a limit isn't removed by accident

The script uses the logged-in WHM root session (the `cpsess` token already in the page URL). No passwords, API tokens, or credentials are stored.

## Files

| File | Purpose |
|---|---|
| `fix-cplimit.sh` | Applies the patch. Safe to run more than once: each run restores the originals and re-applies. |
| `check-limits.sh` | Lists every reseller's real active count and limit from WHM. |

## Requirements

- cPanel/WHM server with root SSH access
- WHMReseller plugin installed at `/usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/`
- Tested with WHMReseller **v5**

## Installation

```bash
# 1. Back up the plugin first
cp -a /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller /root/whmreseller-backup-$(date +%F)

# 2. Get the scripts
git clone https://github.com/<your-username>/whmreseller-cplimit-fix.git
cd whmreseller-cplimit-fix

# 3. Apply the fix
bash fix-cplimit.sh
```

Then reload **WHM → Plugins → WHMReseller → WHM Resellers** with Ctrl+F5:

- The CPs column should show real values such as `4 / 20`.
- **Action → Edit** should show the real number in CPanel Limit instead of `unlimited`.

## Check the real limits

```bash
bash check-limits.sh
```

Example output:

```
reseller1            active=4     limit=20
reseller2            active=11    limit=10  <-- at/over limit
```

A reseller over its limit keeps its existing accounts but can't create new ones until you raise the limit or remove accounts.

To set a limit by hand:

```bash
whmapi1 setresellerlimits user=<reseller> enable_account_limit=1 account_limit=20
```

## Undo

The patch keeps `.orig` copies of every template it changes:

```bash
cd /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates
for f in whmentry editwhm rootmainpage; do cp -a $f.orig $f; done
```

## Notes

- The patch doesn't change any limits itself. It shows the real values and stops the Edit form from saving `unlimited` by accident.
- After editing any reseller, run `bash check-limits.sh` to confirm the limit is still set.
- Only the root view (`rootmainpage`) is patched. Alpha and Master reseller views are unchanged.
- A plugin update or reinstall may overwrite the templates. If that happens, run `bash fix-cplimit.sh` again.
- If the column still shows `∞`, open the browser console (F12 → Console) and check for errors.

## Disclaimer

This project is not affiliated with or endorsed by the WHMReseller developers. Use it at your own risk, and always back up first.
