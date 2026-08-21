# TossNote Website

This folder is designed for GitHub Pages.

The landing page is bilingual. The language toggle is in the top-right corner, and the selected language is saved in the browser.

## Deploy

1. Create a GitHub release (for example, `v1.0.1`).
2. Upload the DMG as a release asset named exactly `TossNote.dmg`.
3. In GitHub repository settings, open `Pages`.
4. Set the source to `Deploy from a branch`.
5. Select branch `main` and folder `/docs`.

The download button points to:

```text
https://github.com/xemina/TossNote/releases/latest/download/TossNote.dmg
```

This always resolves to the newest non-prerelease GitHub Release. Keep the asset name `TossNote.dmg` for every release.

When you buy a domain, add it in GitHub Pages custom domain settings. GitHub will create or use a `CNAME` file in this folder.
