# Delivery plan

## Current status — October 7, 2026

- PRs #1–#3 are merged: native SwiftUI foundation, email accounts/private profiles, and separation of core behavior from Supabase integration.
- Hosted profile schema is applied and its ownership/validation checks passed. Resend domain verification and email-code delivery are working, as reported by the owner.
- Documentation PR #4 records hosted setup, the architecture review, and this plan. It requires owner review before merging.
- Full device acceptance of profile save/edit, relaunch/session restoration, offline save recovery, and sign-out remains. Email delivery alone does not validate all of signup.

## Implementation sequence

Each numbered increment is a focused PR with behavior, validation, and limitations explained. The owner reviews code and tests before merge.

1. **Finish signup acceptance.** Run the device checklist in `backend-setup.md`; fix any demonstrated failures in a focused PR. Keep Scottsdale fixed and GPS deferred.
2. **Account deletion.** Add an authenticated server operation and in-app confirmation that remove the signed-in account and private profile. Test ownership and failure recovery. Extend cleanup as media and connections are introduced. Ship before collecting photos from external testers.
3. **Photo submission.** Add a selected profile photo, a camera-captured verification selfie, clear consent, private storage, and pending/retry states. Implement a separate photo-submission model/service and use the app's shared authenticated client. Use platform photo selection/camera APIs; no paid face-recognition provider. Test object ownership, file limits, retries, and rejection of client approval attempts; test camera capture on a real iPhone.
4. **Manual review and media cleanup.** Provide an authenticated reviewer workflow with server-controlled reviewer access, approve/reject reasons, and resubmission. Approval must refer to the submitted photo version; replacing a photo requires review again. Agree on consent text, reviewer, selfie retention deadline, and deletion behavior before collecting selfies. Enforce cleanup server-side. Test reviewer authorization and expiry/deletion. Manual selfie comparison does not establish legal identity or age.
5. **Scottsdale discovery and matching.** Show only approved profiles through a limited public read model without birthdays, emails, or selfies. Add check/pass, transactional mutual matches, and an honest empty state. Add block/report/unmatch with server enforcement in the same release before external discovery. Test duplicate actions, mutual-match creation, approval changes, and blocked-user visibility.
6. **Match-only chat.** Persist conversations for mutual matches, then add live updates and pagination. Enforce membership and blocking on the server. Test unauthorized reads/writes and match removal. Extend account deletion and moderation to messages.
7. **Field pilot and investor demo.** Add shareable invitation/QR entry points and recruit real volunteers. Complete brand assets, device QA, privacy/community/support material, and TestFlight setup. Confirm Apple membership and release signing status. Demo real accounts, approved profiles, a mutual match, and a conversation; no invented people or fake verification.

## Cost and scope

Use the existing Supabase project and Resend free tier initially, plus the registered domain. Check current quotas before increasing tester numbers. Manual review avoids an initial paid verification service. Email codes handle account access; selfie review handles photo consistency. Location permission, SMS authentication, and Apple sign-in are deferred unless the pilot demonstrates a need.

## Acceptance and documentation

Keep app rules in the core package, backend operations in the integration package, and feature UI under `App/Features`. Add shared infrastructure only when the next feature needs it. Update architecture and setup instructions with each increment, and include migrations and permission tests alongside any schema/storage changes.

Before external photo testing, establish a designated reviewer, retention/consent decisions, support contact, privacy policy, and community rules. Before TestFlight, confirm paid Apple membership, final bundle identifier, signing, app icon, and App Store Connect access.
