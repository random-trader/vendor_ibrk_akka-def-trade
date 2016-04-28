
/*
 * Passive Agressive Record: basic idea: CR<strike>UD</strike> enforced through repository methods
 * 
 * - decouple the notion of the entity id in the domain model 
 *   (which has continutity over evolution of the entity state)
 *   from the primary key in the db (which is different for every state change in the entity)
 * 
 * - entity id within the domain model has no naming convention...
 *   however a single non-unique index ending in _eid indicates an entity id on the column(s) referenced
 * 
 * - 'id' is a distinguished name and always serial4 or serial8 primary key
 *   guaranteed ascending as time evolves
 * 
 * - optional ts: timestamptz field when recording time of state change is necessary
 * 
 * - 'validity' as a concept is the responsibility of the domain model! no global
 *   (repository methods return the latest record for a given entity id)
 *   up to model to determine if this is valid
 *   prefix function isValid to be defined on record
 * 
 */

/*
http://stackoverflow.com/questions/1884758/generate-ddl-programmatically-on-postgresql
*/
--
-- PIENET = a reactive pizza service
--  - online ordering 
--  - robotic kitchens
--  - drone delivered
--  - BTC payments
--
drop type if exists pizza_size_e cascade;
create type pizza_size_e as enum (
  'slice', 
  'small', 
  'med', 
  'large'
);

drop type if exists pizza_topping_e cascade;
create type pizza_topping_e as enum (
  'mozzarella', 
  'pepperoni', 
  'feta', 
  'sausage', 
  'ham', 
  'onions',
  'peppers',
  'pineapple',
  'olives',
  'mushrooms'
);

drop type if exists order_status_e cascade;
create type order_status_e as enum (
  'submitted', 
  'quoted', 
  'confirmed', 
  'queued', 
  'prepared', 
  'delivered', 
  'canceled'
);

drop table if exists pizzas cascade;
create table pizzas (

  id serial4 primary key,

  name varchar(126) unique not null, -- this is the entity identity for the domain model
  toppings pizza_topping_e[] not null,
  meta jsonb not null,
  
  span tstzrange not null
);
create index pizzas_span on pizzas using gist(span);
create index pizzas_meta_index on pizzas using gin (meta);

-- want constant id as user evolves (e.g. changes contact info)
drop table if exists users cascade;
create table users (

  id serial8 primary key,
  
  user_name varchar(126) unique not null, -- domain model must ensure uniqueness within domain
  signup timestamptz not null,            -- never changes for a given user name
  btc_addr varchar(35) not null,          -- can change
  meta jsonb not null,                    -- can change
  
  span tstzrange not null
);
create index users_span on users using gist(span);
create index users_meta_index on users using gin (meta);

drop table if exists orders cascade;
create table orders (

  id serial8 primary key,
  
  uuid UUID unique not null,
  user_id int4 references users(id) not null,
  deliver_to jsonb not null,
  est_delivery interval not null,
  status order_status_e not null,
  
  span tstzrange not null
);
create index orders_span on orders using gist(span);
create index orders_deliver_to on orders(deliver_to);
--
-- note - because prices are quoted in BTC, every order item will vary due to BTC volatility.
-- (the real time pricing engine is proprietary to PIENET).
--
drop table if exists order_items cascade;
create table order_items (

  id serial8 primary key,
  
  pizza_id int4 references pizzas(id) not null,
  pizza_size pizza_size_e not null,
  quantity int2 default 1 not null,
  unit_price money default (1.0) not null, -- in BTC - negative indicates order not yet quoted
  requests jsonb not null
);

drop table if exists order_item_links cascade;
create table order_item_links (
  order_id int8 references orders(id) not null,
  order_item_id int8 references order_items(id) not null,
  primary key (order_id, order_item_id)
);


insert into pizzas (name, toppings, span) values 
  ('cheese', '{"mozzarella"}', '[12/21/2012,)'),
  ('pepperoni', '{"mozzarella", "pepperoni"}', '[12/21/2012,)'),
  ('mushroom', '{"mozzarella", "mushrooms"}', '[12/21/2012,)'),
  ('greek', '{"feta", "sausage", "olives", "onions", "peppers"}', '[12/21/2012,)'),
  ('hawaiian', '{"mozzarella", "ham", "pineapple"}', '[12/21/2012,)');