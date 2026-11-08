# LiftLog Version 1

Implement the approved core release: offline workout tracking, an exercise catalogue with form cues, a persistent active workout timer, set entry, history and editing, basic progress, units and settings. Use GetX routing, dependency bindings and reactive controllers. No accounts, backend, subscription, or forced updates.

Visual source: ../../../visuals.md and screenshot/. Background #10110F, surface #1C1E1A, lime #D5FF3F, primary text #F5F5EF and secondary #A8ACA0. Rounded 20–24px cards, large bold headlines, lime primary actions, clean compact set-entry rows and a consistent bottom navigation. Use genuine empty states and actual recorded data. Offline exercise form cues ship with the app. Professional demonstration media, photos, social sharing and CSV backup belong to the subsequent plan stages.

Architecture: immutable serializable domain models; an atomic local Sembast repository with a schema version; one application-level GetX workout controller coordinating persistence; small feature pages; central theme, routes and formatters. Weight is stored in kg and converted for lb display and input. Persist a draft on every meaningful edit, derive elapsed time from the start timestamp, and support resume/discard after restart. Save failures keep the previous state and display a retry message.

Play Store updates: user-initiated check in Settings, Android flexible update only, optional download and optional restart. Skip or failure leaves all app features accessible. Never use immediate update, minimum-version lock, startup gate or login. Version starts at 1.0.0+1. Schema readers accept supported data and never overwrite unknown future versions. Release signing and a permanent application ID must be configured before actual Play publication.
