# Profile presentation and photo actions

The shared profile card gives details a flexible text column and Discovery actions a separate fixed-width column beneath the image. Connect appears above Pass at the image's trailing edge. Long text and Dynamic Type grow vertically rather than laying out behind the buttons. Read-only cards omit the action column.

On initial account restoration, the loading screen owns its one progress indicator; the shared busy footer renders only for other onboarding states. Profile-photo loading remains owned by the profile view after restoration finishes.

An empty photo sheet shows a single **Choose your photo** picker label with an image icon. No empty photo heading, placeholder or empty review description is rendered. A valid, complete unsaved selection enables Save; saving still closes the sheet on success. Remove appears only for remotely stored files, including a previously stored selfie, and stays available after an uncertain removal failure. Selecting a new local image alone does not imply files exist remotely. Review-required selfie capture retains its separate explanation and readiness requirement.

The photo model owns `canSave` and `hasStoredPhotos`, with lifecycle tests covering new selection, failed save, saved replacement, failed removal and successful removal. Offline iPhone journeys cover empty/saved photo sheets, startup loading and decision-column geometry. Camera/photo-library acceptance still needs an actual iPhone.
