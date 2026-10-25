begin;

-- Move only the existing choices whose order changes into unused temporary slots.
-- This avoids collisions with the unique (category_id, sort_order) constraint.
update private.interest_options as option
set sort_order = reordered.position + 100
from (values
    ('gym', 3), ('running', 4), ('basketball', 6), ('tennis', 7),
    ('cooking', 4), ('barbecue', 5), ('wine', 7)
) as reordered(id, position)
where option.id = reordered.id;

update private.interest_options
set sort_order = sort_order - 100
where id in ('gym', 'running', 'basketball', 'tennis', 'cooking', 'barbecue', 'wine');

-- Match the owner's proposed labels and order. IDs stay stable independently of labels.
-- All seven are selectable now; active=false can reserve future options in the backend.
insert into private.interest_options(id, category_id, title, sort_order, active) values
    ('gun_range', 'sports_fitness', 'Gun Range', 2, true),
    ('combat_sports', 'sports_fitness', 'Combat Sports', 5, true),
    ('tsls', 'food_drinks', 'TSL''s', 3, true),
    ('dive_bars', 'food_drinks', 'Dive Bars', 6, true),
    ('diy', 'social_hobbies', 'DIY', 6, true),
    ('mogging', 'social_hobbies', 'Mogging', 7, true),
    ('poker', 'social_hobbies', 'Poker', 8, true);

commit;
