# Delivery plan

1. **Foundation (PR #1):** buildable iOS project, welcome and pilot overview, visual tokens, configuration validation, tests, and CI.
2. **Email accounts and private profiles (complete):** email OTP, age eligibility, job title, activity summary, session restore, and hosted signup. Account deletion and private photos are implemented.
3. **Photo review (optional pilot feature):** consent, selfie capture, and private storage are implemented. Review defaults off through a server flag. Reviewer queue, approval operations, audit, and automatic retention remain before enabling review.
4. **Discovery and connection (complete):** opt-in Scottsdale visibility, check/pass, mutual connections, blocking, and authorization tests. GPS/proximity is deferred.
5. **Messaging and safety (schema review):** match-only chat, report/unmatch/unblock, moderation handling, and support/privacy materials. Blocking and account deletion are already implemented.
6. **Field pilot:** invitation links/QR codes, real volunteer profiles, final brand assets, device QA, and TestFlight distribution.

Each increment gets a separate reviewable PR. The foundation is not the investor-ready demo; the field pilot needs the real signup, review, and connection flows.

## External setup

- GitHub access: configured for branches and PRs; owner reviews merges.
- Apple: account added to Xcode; paid membership pending. Signing, final bundle ID, and App Store Connect setup remain.
- Supabase: project created. Profile/photo/discovery schema, policies, and server functions are deployed. Email-code templates and SMTP work. Apple sign-in remains separate work.
- Before collecting user data: support contact, privacy policy, community rules, selfie retention policy, and a designated reviewer.

The first messaging PR begins with an owner-reviewed [schema proposal](messaging-schema-proposal.md). Implementation follows approval; conversation UI is a separate PR. See the [code structure review](code-structure-review.md) for the directory and dependency boundaries.
