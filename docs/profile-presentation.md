# Profile presentation and photo actions

The shared profile card gives details a flexible text column and Discovery actions a separate fixed-width column beneath the image. Connect appears above Pass at the image's trailing edge. Long text and Dynamic Type grow vertically rather than laying out behind the buttons. Read-only cards omit the action column.

On initial account restoration, the loading screen owns its one progress indicator; the shared busy footer renders only for other onboarding states. Profile-photo loading remains owned by the profile view after restoration finishes.

An empty photo editor shows a single **Upload** action with an image icon. No empty photo heading, placeholder or empty review description is rendered. A valid, complete unsaved selection enables Save; saving returns to the previous screen on success. Remove appears only for remotely stored files, including a previously stored selfie, and stays available after an uncertain removal failure. Selecting a new local image alone does not imply files exist remotely. Review-required selfie capture retains its separate explanation and readiness requirement.

The photo model owns `canSave` and `hasStoredPhotos`, with lifecycle tests covering new selection, failed save, saved replacement, failed removal and successful removal. Offline iPhone journeys cover empty/saved photo editors, startup loading and decision-column geometry. Camera/photo-library acceptance still needs an actual iPhone.

## Profile editor navigation

Profile has one text-only **Edit Profile** action. It opens `ProfileEditorMenuView`, a modal menu with **Photos**, **About Me**, and **Interests**. Each section pushes onto the menu's existing navigation stack: it enters from the right, and **Back** pops it to the right. Saving also returns to the menu; **Close** dismisses the menu to the profile tab. The About Me form contains name, job title, bio, birthday, and city. The menu Close and section Back controls have distinct accessibility identifiers.

`EditorPage` hosts pushed or standalone editors; `EditorExitGuard` shares busy-state and discard protection with `EditorSheet`. Back and dismissal are disabled while saving or preparing a photo. Back from an unsaved About Me or Interests editor discards its local draft; Photos retains its explicit discard warning, including attempted sheet dismissal. Successful photo saves/removals publish the persisted images to the profile before returning to the menu, without a second download.

`ProfileHomeView` presents the editor menu as a sheet. Its empty **Add a photo** frame pushes Photos directly on the profile stack; Back returns directly to the profile. Returning reloads public interests and refreshes photos when needed. Discovery filter editing still uses Preferences navigation; the interest form supports both presentations without duplicating selection rules.

`ProfileEditorView` reuses the `ProfileForm` in `App/Features/Profile` with a separate draft. `OnboardingModel.updateProfile` validates and saves the current account’s existing profile, then publishes the normalized draft while remaining in the saved-account state. Signup retains its own first-profile save path. Failed, invalid, and cancelled edits never publish a draft as a successful save. The obsolete transition from the signed-in profile back to onboarding editing is removed.

Core tests cover validation, failed-save retry, normalization, cancellation, and retaining the signed-in state. Simulator journeys check Back from all three sections, discarded unsaved fields/interests, saving back to the updated profile, and the separate Discovery interest filters. The Discovery layout journey also verifies that the block action is absent.
