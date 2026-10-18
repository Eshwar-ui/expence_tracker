# Login design audit — 19 October 2026

## Critical — completed
- Constrain content width; allow the account switch to wrap rather than overflow.
- Keep the full form scrollable in a limited viewport.
- Give Google sign-in a visible outline and align it with the email sign-in controls.

## Refinement — completed
- Reduce the logo from 104px to 72px and remove its redundant surrounding tile.
- Use consistent 20px gutters, 16px field gaps and 24px section gaps.
- Reduce the empty gap between password recovery and the primary action.
- Preserve the frosted glass panel with translucent fields and a subtle lavender,
  pearl and mint gradient; provide a navy/violet/teal dark version.

## Polish — completed
- Add password visibility tooltips and clearer placeholder contrast.
- Brighten dark-mode links; reuse existing design-system spacing and radii.

## Verification
- Flutter analyzer passed for both changed Dart files.
- Android debug APK built successfully.
- Inspected normal-width light/dark layouts and compact 320dp layout, including
  scrolling to secondary actions. No layout overflow observed.
- Sign-in, Google authentication and password reset callbacks remain unchanged.
- No account submission was performed during the visual review.
