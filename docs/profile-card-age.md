# Age on profile cards

The shared `ProfileCard` displays age beside the name on the owner’s profile,
Discovery, Connections, and profiles opened from Messages. The owner’s age is
calculated from their private birthday using `BirthDate.age`. Other profiles
receive only an integer `age`, calculated by PostgreSQL in the existing authorized
Discovery and conversation projections. Both calculations use UTC calendar dates;
February 29 birthdays advance on March 1 in non-leap years.

`DiscoveryProfile.age` is optional for compatibility with older backend responses.
A missing age is omitted from the card; the app never guesses an age. Existing
eligibility checks, RLS, photo signing, and function permissions are unchanged.

## Deployment

Apply `20261114210537_profile_card_age.sql`, then deploy `discovery` and `messaging`
with their shared dependencies and JWT verification enabled. Release the updated
iPhone build afterward. No new table columns, seed refresh, or Auth changes are
needed. Git merges do not deploy backend changes.

Deployed November 14, 2026 to **newtotown-test** (`acmrnolvakubxnaxwpzt`): migration
`20261114210537`, Discovery v4, and Messaging v4. Production is unchanged.

## Verification

- Swift tests cover birthday boundaries, leap years, invalid dates, and decoding
  both current and older responses.
- SQL preference tests exercise candidate, connection, and conversation ages and
  verify that birthday fields remain private.
- Edge Function tests verify public age projection and private-field exclusion.
- Simulator tests check age beside the name on owner and Discovery cards, plus
  the decision column with long profile text.

Hosted acceptance also verified an authenticated seeded account could load 20
Discovery cards with ages, download a signed private photo, and load its inbox.
The synthetic sign-in sent no email/SMS and its temporary session was signed out.
