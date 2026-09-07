# Delivery plan

1. **Foundation (this PR):** buildable iOS project, welcome and pilot overview, visual tokens, configuration validation, tests, and CI.
2. **Accounts and profiles:** Apple/email authentication, 18+ onboarding, job title, activity summary, photo upload, database migrations and RLS tests. Validate email delivery configuration before inviting real users.
3. **Photo review:** consent, verification selfie capture, private storage, reviewer queue, approval/rejection, retention and deletion. Only approved profiles become discoverable.
4. **Discovery and connection:** Scottsdale selection, check/pass, mutual matches, and authorization tests. GPS/proximity is deferred.
5. **Messaging and safety:** match-only chat, block/report/unmatch, moderation, and account deletion.
6. **Field pilot:** invitation links/QR codes, real volunteer profiles, final brand assets, device QA, and TestFlight distribution.

Each increment gets a separate reviewable PR. The foundation is not the investor-ready demo; the field pilot needs the real signup, review, and connection flows.

## External setup

- GitHub access: configured for branches and PRs; owner reviews merges.
- Apple: account added to Xcode; paid membership pending. Signing, final bundle ID, and App Store Connect setup remain.
- Supabase: project created. No schema, RLS policies, storage buckets, or auth providers configured by this code yet.
- Before collecting user data: support contact, privacy policy, community rules, selfie retention policy, and a designated reviewer.
