# Subtle workout feedback

Approved in chat: keep motion limited to three moments.

- Successful Finish workout: six small lime sparkles around the existing summary checkmark for one second. Never replay when opening history or editing a saved workout. No overlay or blocked interaction.
- Welcome back: fade the greeting for 650 ms once per app launch, without translating the headline or replaying on tab changes. Start after the page is visible and its transition completes.
- Set completion: scale the check button up to 1.10 and back over 300 ms only after an unchecked set saves as completed. Add a slim per-exercise progress bar that updates over 220 ms. Existing completed sets do not pop on mount.
- Reduced motion: greeting and progress appear immediately; no sparkles or button scaling. No dependencies, sounds, haptics, or changes to workout persistence.

Visibility correction after user feedback: both greeting and sparkles wait for the incoming route transition, including Navigator's offstage measurement frame. The same six local sparkles use slightly larger marks with a short brightness hold, still ending in one second.
