begin;

-- Cover both columns of the category/option foreign keys while retaining option-first
-- lookups used by matching. User IDs complete the lookup for a particular profile.
create index profile_interest_category_options on private.profile_interest_selections(option_id, category_id, user_id);
create index discovery_interest_category_options on private.discovery_interest_filters(option_id, category_id, user_id);
drop index private.profile_interest_options;
drop index private.discovery_interest_options;

commit;
