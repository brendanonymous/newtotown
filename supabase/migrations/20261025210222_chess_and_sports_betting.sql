begin;

-- Chess is a distinct interest; retain Board games and its saved selections.
-- Inactive rows still occupy their sort position, so free position zero first.
update private.interest_options
set active = false, sort_order = 10
where id = 'board_games';

insert into private.interest_options(id, category_id, title, sort_order, active) values
    ('chess', 'social_hobbies', 'Chess', 0, true),
    ('sports_betting', 'social_hobbies', 'Sports betting', 9, true);

commit;
