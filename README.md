# WHMReseller Fixes

**CP limit and mobile layout fixes for the WHMReseller v5 cPanel/WHM plugin**

Created by **[Sajibe Kanti](https://github.com/Sajibekanti)** · Repository: [github.com/Sajibekanti/whmreseller-cplimit-fix](https://github.com/Sajibekanti/whmreseller-cplimit-fix)

---

The WHMReseller plugin is no longer maintained by its developers. This repository fixes two problems in it, without touching the plugin's compiled program:

| Fix | Problem | Script |
|---|---|---|
| **CP limit** | Every reseller shows `CPs: 4 / ∞`, and saving the Edit form can **remove** the real account limit | `fix-cplimit.sh` |
| **Mobile layout** | On phones, tables run off the screen and the Dash and Tools pages are squeezed unreadable | `fix-mobile.sh` |

## Quick start

```bash
# 1. Back up the plugin
cp -a /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller /root/whmreseller-backup-$(date +%F)

# 2. Download and apply both fixes
git clone https://github.com/Sajibekanti/whmreseller-cplimit-fix.git
cd whmreseller-cplimit-fix
bash fix-cplimit.sh
```

`fix-cplimit.sh` also runs `fix-mobile.sh` for you. To apply only the mobile fix, run `bash fix-mobile.sh` instead.

Then open **WHM → Plugins → WHMReseller** and reload with Ctrl+F5:

- **WHM Resellers** shows real values in the CPs column, such as `4 / 20`. Resellers at or over their limit are shown in red.
- **Action → Edit** shows the real number in CPanel Limit instead of `unlimited`.
- On a phone, each reseller appears as a readable card.

## Requirements

- cPanel/WHM server with root SSH access
- WHMReseller plugin installed at `/usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/`
- Tested with WHMReseller **v5** on cPanel/WHM **134**

## Files

| File | Purpose |
|---|---|
| `fix-cplimit.sh` | Applies the CP limit fix and re-applies the mobile fix. Safe to run more than once. |
| `fix-mobile.sh` | Applies the mobile layout fix. Safe to run more than once, in any order. |
| `check-limits.sh` | Lists every reseller's real account count and limit, straight from WHM. |

---

## 1. CP limit fix

### The problem

On the **WHM Resellers** tab, every reseller's cPanel account limit is shown as unlimited (`∞`), so it looks as though resellers can create as many accounts as they like.

### What is actually happening

The limits **are** set and enforced. The plugin just doesn't display them:

- Each reseller package stores its limit in the plugin's package field `whmrcplimit`, for example `whmrcplimit=20` in `/var/cpanel/packages/<PACKAGE>`.
- The plugin passes that value to WHM with `setresellerlimits` (`enable_account_limit`, `account_limit`).
- `whmapi1 acctcounts user=<reseller>` returns the correct limit, and WHM blocks new accounts once a reseller reaches it.

The plugin's compiled program (`subreseller.cgi`) never fills the `$CPLIMIT` placeholder for WHM-type resellers, so the page falls back to `∞`.

### Why it matters: the Edit form can remove limits

The **Edit WHM** form has the same bug: its **CPanel Limit** field loads as `unlimited`. If you save the form, for example to change only the disk limit, that `unlimited` is sent back to WHM, and the reseller's real limit is likely **removed**. A display bug can therefore turn into a real unlimited reseller.

### How the fix works

The compiled program can't be edited, but it reads plain-text templates. `fix-cplimit.sh` patches three of them:

1. **`templates/whmentry`** (list row): tags the CPs cell with the reseller's username.
2. **`templates/editwhm`** (edit form): tags the CPanel Limit field with the reseller's username.
3. **`templates/rootmainpage`**: adds a small script that reads each reseller's real limit from WHM's own API (`acctcounts`) and:
   - shows the real limit and account count in the list, in **red** when a reseller is at or over its limit
   - **fills in the Edit form's CPanel Limit** with the real limit
   - **asks for confirmation** before saving a reseller (edit, create, upgrade or downgrade) with an empty or `unlimited` CPanel Limit

The script uses your logged-in WHM root session. No passwords, API tokens or other credentials are stored.

---

## 2. Mobile layout fix

### The problem

The plugin uses fixed-width columns and wide tables. On a phone:

- **WHM Resellers**: the table runs off the right side of the screen.
- **Dash**: the stats list is squeezed until words break letter by letter.
- **Tools**: the two panels sit side by side and become too narrow to read.

### How the fix works

`fix-mobile.sh` adds a style and script block to `rootmainpage`, `alphamainpage` and `mastermainpage`. It only takes effect on screens narrower than 768px, so **desktop is unchanged**. On phones:

- **Tables become cards**: one card per reseller or account, with `Label: value` lines taken from the table headers. The Action menu still works.
- **The tab bar** scrolls sideways instead of wrapping onto several lines.
- **Columns stack**: the Dash stats, history charts and Tools panels each use the full width, and charts redraw at the new size.
- **Dialogs** (Edit, Create and so on) use the full screen width.

---

## Checking the real limits

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

**Tip:** run `check-limits.sh` after editing any reseller, to confirm its limit is still set.

## Updating

```bash
cd whmreseller-cplimit-fix
git pull
bash fix-cplimit.sh
```

If the plugin is ever updated or reinstalled, its templates may be overwritten. Run `bash fix-cplimit.sh` again to restore both fixes.

## Undo

The scripts keep `.orig` copies of every template they change.

```bash
cd /usr/local/cpanel/whostmgr/docroot/cgi/whmreseller/templates

# Undo everything
for f in whmentry editwhm rootmainpage alphamainpage mastermainpage; do
  [ -f $f.orig ] && cp -a $f.orig $f
done

# Or undo only the mobile fix
for f in rootmainpage alphamainpage mastermainpage; do
  sed -i '/WHMR-MOBILE-FIX BEGIN/,/WHMR-MOBILE-FIX END/d' $f
done
```

## Troubleshooting

| Symptom | What to check |
|---|---|
| CPs still shows `∞` | Reload with Ctrl+F5. If it persists, open the browser console (F12 → Console) and look for errors. |
| `check-limits.sh` shows `NONE (unlimited)` | That reseller really has no limit. Set one with `whmapi1 setresellerlimits` (see above). |
| `pattern not found` when running a script | The plugin's templates differ from v5. Open an issue and include the output. |

## Notes

- The CP limit fix doesn't change any limits itself. It shows the real values and stops the Edit form from saving `unlimited` by accident.
- The CP limit fix covers the root view. The mobile fix covers the root, Alpha and Master views.

## Credits

- **Author:** [Sajibe Kanti](https://github.com/Sajibekanti)

Found a bug or have an improvement? [Open an issue](https://github.com/Sajibekanti/whmreseller-cplimit-fix/issues) or send a pull request.

## Disclaimer

This project is not affiliated with or endorsed by the WHMReseller developers. Use it at your own risk, and always take a backup before applying any changes.
