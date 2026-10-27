# Profile presentation and photo actions

The shared profile card gives details a flexible text column and Discovery actions a separate fixed-width column beneath the image. Connect appears above Pass at the image's trailing edge. Long text and Dynamic Type grow vertically rather than laying out behind the buttons. Read-only cards omit the action column.

On initial account restoration, the loading screen owns its one progress indicator; the shared busy footer renders only for other onboarding states. Profile-photo loading remains owned by the profile view after restoration finishes.

An empty photo sheet shows a single **Choose your photo** picker label with an image icon. No empty photo heading, placeholder or empty review description is rendered. A valid, complete unsaved selection enables Save; saving still closes the sheet on success. Remove appears only for remotely stored files, including a previously stored selfie, and stays available after an uncertain removal failure. Selecting a new local image alone does not imply files exist remotely. Review-required selfie capture retains its separate explanation and readiness requirement.

The photo model owns `canSave` and `hasStoredPhotos`, with lifecycle tests covering new selection, failed save, saved replacement, failed removal and successful removal. Offline iPhone journeys cover empty/saved photo sheets, startup loading and decision-column geometry. Camera/photo-library acceptance still needs an actual iPhone.

## Profile editor sheets

Profile has one text-only **Edit Profile** action. It opens `ProfileEditorMenuView`, a modal menu with **Photos**, **About Me**, and **Interests**. Each section opens its existing modal editor using the shared `EditorSheet` navigation container. Closing or successfully saving a section returns to the menu; closing the menu returns to the profile tab. The About Me form contains name, job title, bio, birthday, and city. The menu and section Close controls have distinct accessibility identifiers to avoid ambiguous actions when sheets are stacked.

The container disables Close and swipe dismissal while saving or preparing a photo. Closing an unsaved About Me or Interests editor discards its local draft; Photos retains its explicit discard warning. Successful photo saves/removals publish the persisted images to the profile before returning to the menu, without a second download.

`ProfileHomeView` owns a single optional editor destination, so it cannot present competing sheets. Returning reloads public interests and refreshes photos when needed. Discovery filter editing still uses Preferences navigation; the interest form supports both presentations without duplicating selection rules.

`ProfileEditorView` reuses the `ProfileForm` in `App/Features/Profile` with a separate draft. `OnboardingModel.updateProfile` validates and saves the current account’s existing profile, then publishes the normalized draft while remaining in the saved-account state. Signup retains its own first-profile save path. Failed, invalid, and cancelled edits never publish a draft as a successful save. The obsolete transition from the signed-in profile back to onboarding editing is removed.

Core tests cover validation, failed-save retry, normalization, cancellation, and retaining the signed-in state. Simulator journeys check all three Close actions, discarded unsaved fields/interests, saving back to the updated profile, and the separate Discovery interest filters. The Discovery layout journey also verifies that the block action is absent.
