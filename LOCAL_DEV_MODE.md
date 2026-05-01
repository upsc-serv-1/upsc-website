# Local Dev Mode

Load test files directly from your computer instead of Supabase - saves your hosting quota!

## How to Use

### 1. Start Local Dev Mode
Add `?local=true` to your URL:
- Local: `http://localhost:3000/?local=true`
- Netlify: `https://yoursite.netlify.app/?local=true`

You'll see an orange **"LOCAL"** badge in the header.

### 2. Add New Test Files

1. **Copy your JSON file** to `src/data/imports/`
2. **Update the index** by running:
   ```powershell
   # Right-click this file → "Run with PowerShell"
   .\tools\update-imports-index.ps1
   ```
3. **Refresh** your browser with `?local=true`

### 3. Exit Local Mode
- Just remove `?local=true` from URL, or
- Use `?local=false`

## What Works

✅ Test files load from local folder (no Supabase calls)
✅ User data (attempts, notes, settings) still syncs to Supabase
✅ All features work normally

## Files Involved

| File | Purpose |
|------|---------|
| `src/data/imports/` | Drop your JSON test files here |
| `src/data/imports/index.json` | Auto-generated list of files |
| `tools/update-imports-index.ps1` | Run this after adding files |
| `src/modules/local-imports.js` | The local loader code |

## Need to Regenerate Index?

After adding/removing files in `src/data/imports/`, run the PowerShell script to update `index.json`.

Or manually edit `src/data/imports/index.json` and add your file to the list.
