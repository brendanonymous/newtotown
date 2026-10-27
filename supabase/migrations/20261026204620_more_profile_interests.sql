begin;

-- Append choices in free positions; keep every existing ID, order and selection.
insert into private.interest_options(id, category_id, title, sort_order, active) values
    ('soccer', 'sports_fitness', 'Soccer', 20, true),
    ('baseball', 'sports_fitness', 'Baseball', 21, true),
    ('swimming', 'sports_fitness', 'Swimming', 22, true),
    ('yoga', 'sports_fitness', 'Yoga', 23, true),
    ('volleyball', 'sports_fitness', 'Volleyball', 24, true),
    ('trail_running', 'outdoors', 'Trail running', 20, true),
    ('rock_climbing', 'outdoors', 'Rock climbing', 21, true),
    ('paddleboarding', 'outdoors', 'Paddleboarding', 22, true),
    ('skiing', 'outdoors', 'Skiing', 23, true),
    ('backpacking', 'outdoors', 'Backpacking', 24, true),
    ('brunch', 'food_drinks', 'Brunch', 20, true),
    ('food_trucks', 'food_drinks', 'Food trucks', 21, true),
    ('sushi', 'food_drinks', 'Sushi', 22, true),
    ('pizza', 'food_drinks', 'Pizza', 23, true),
    ('baking', 'food_drinks', 'Baking', 24, true),
    ('festivals', 'arts_entertainment', 'Festivals', 20, true),
    ('art_galleries', 'arts_entertainment', 'Art galleries', 21, true),
    ('podcasts', 'arts_entertainment', 'Podcasts', 22, true),
    ('painting', 'arts_entertainment', 'Painting', 23, true),
    ('dancing', 'arts_entertainment', 'Dancing', 24, true),
    ('trivia', 'social_hobbies', 'Trivia', 20, true),
    ('travel', 'social_hobbies', 'Travel', 21, true),
    ('language_exchange', 'social_hobbies', 'Language exchange', 22, true),
    ('entrepreneurship', 'social_hobbies', 'Entrepreneurship', 23, true),
    ('personal_finance', 'social_hobbies', 'Personal finance', 24, true);

commit;
