# Visual Reference Analysis

## Sources reviewed

Reviewed all four PNG files in `screenshot/`:

- `Screenshot 2026-11-07 at 23.10.42.png`
- `Screenshot 2026-11-07 at 23.11.12.png`
- `Screenshot 2026-11-07 at 23.11.37.png`
- `Screenshot 2026-11-07 at 23.12.06.png`

The folder also contains `.DS_Store`, which is macOS metadata rather than a visual reference.

## Overall visual direction

The references share a bold, modern fitness aesthetic: near-black backgrounds, vivid chartreuse/lime highlights, high-contrast white text, and large photography of people exercising. The interface feels energetic and premium while using simple rounded surfaces and clear navigation. The lime is a signature accent used sparingly for selected states, key actions, progress, and short headline emphasis.

## Color and contrast

- **Main background:** very dark charcoal or black.
- **Cards and secondary surfaces:** charcoal/graphite, subtly lighter than the background.
- **Primary accent:** electric yellow-green / chartreuse.
- **Text:** white for primary content; soft gray for supporting labels and inactive controls.
- **Occasional light surfaces:** warm off-white appears in some activity cards, but the dominant product shell remains dark.
- Keep lime accent text and controls legible against both dark and bright surfaces. Avoid using the accent for long paragraphs.

## Typography and tone

- Use a clean, bold sans-serif with strong weight contrast.
- Headlines are large and direct; key words may be highlighted in lime.
- Supporting text is short, calm, and readable, with muted secondary labels.
- Some references use handwritten-style annotations as decorative image overlays. Treat this as an optional accent, not the main app typeface.

## Layout and components

- Mobile-first, edge-to-edge screens with generous spacing and a clear content hierarchy.
- Rounded cards and pill-shaped category filters, chips, and buttons.
- Strong image cards for workouts or exercises, with a dark gradient behind text when needed.
- Simple progress visuals: rings, bars, small trend lines, and highlighted selected dates.
- Prominent primary action buttons, often full-width and lime-filled with dark text.
- Bottom navigation appears consistently in the reference apps; selected destinations use lime iconography or a lime circular action button.
- Search, filter, and sort controls sit together near the top of browse screens.

## Imagery and motion

- Use motivating, realistic fitness photography with confident but approachable subjects and varied body types.
- Exercise detail screens foreground a person performing the movement; the exercise name, step count or duration, and progress indicator overlay the image.
- Exercise demonstrations should be easy to replay and understand. The reference direction supports image-led instruction screens with previous/next controls and a visible skip action.
- Workout completion can use a focused celebratory state with a large checkmark and one clear next action.
- Prefer restrained, useful motion: progress animation, timer transitions, and small feedback when a set is logged. Avoid motion that slows down workout entry.

## Screen implications for this app

- **Home:** dark canvas, a vivid Start Workout action, recent workout card, and concise progress indicators.
- **Active workout:** prioritize readability and fast set entry; keep the elapsed timer visible and use lime for the active state and primary controls.
- **Exercise library/detail:** photo or animation-led cards, clear search and filters, then simple cues and demonstration controls.
- **Progress:** dark cards with lime chart lines, bars, or rings; provide labels and values so color is not the only way to read the chart.
- **Workout summary/share:** use a strong photo option, large duration and workout highlights, and a share action that can produce a clean social image.
- **Settings/data:** retain the same dark surfaces, but favor plain labels and understandable import/export actions over decorative elements.

## Practical design principles

1. Preserve the dark + chartreuse identity while keeping text and interactive states accessible.
2. Make workout logging faster and clearer than discovery or social content; these references contain community and nutrition features that are not part of the agreed app scope.
3. Use imagery to support exercise understanding, but do not let large images crowd set entry or progress data.
4. Keep the screen system consistent: shared spacing, corner radii, card treatment, icon weight, and button hierarchy.
5. Design empty, loading, and offline states within the same visual system. The app should remain useful without an account or network connection.
6. Do not copy unrelated reference features such as social groups, calories, hydration, trainers, subscriptions, or daily step goals unless those are explicitly added to scope later.

## Items to decide during design

- Final lime/chartreuse and charcoal color values.
- Whether the app uses dark mode only or also offers a light theme.
- Whether workout guidance uses looping animation, short video, or illustrated frames, considering offline availability and app size.
- Which photography style and licensing/source approach to use.
- Navigation labels and exact placement of the primary Start Workout action.
