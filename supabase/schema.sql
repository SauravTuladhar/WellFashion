-- WellFashion database schema, Row Level Security policies, and seed data.
-- Run this once, in full, in your Supabase project's SQL Editor
-- (Project -> SQL Editor -> New query -> paste this entire file -> Run).
-- Safe to re-run on a fresh project; it is NOT safe to re-run on a project
-- that already has these tables (the seed inserts would duplicate/conflict).

create extension if not exists pgcrypto;

-- ===================== TABLES =====================

create table categories (
  slug text primary key,
  label text not null,
  icon text not null,
  sort_order int not null
);

create table products (
  id text primary key,
  name text not null,
  price numeric not null,
  old_price numeric,
  category_slug text not null references categories(slug),
  img text not null,
  description text,
  rating numeric not null,
  reviews int not null,
  flash boolean not null default false,
  sold int,
  stock int not null default 100
);

create table product_images (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references products(id) on delete cascade,
  url text not null,
  created_at timestamptz not null default now()
);

-- Customer ratings + written reviews, gated to verified purchasers (see the
-- "verified purchaser insert review" policy below). products.rating/reviews
-- are auto-recomputed from these via the recompute_product_rating() trigger
-- near the end of this file.
create table product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references products(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reviewer_name text not null,
  rating int not null check (rating between 1 and 5),
  body text,
  created_at timestamptz not null default now(),
  unique (product_id, user_id)
);

-- One row per auth.users row; created automatically by the trigger below.
-- is_admin is never self-serve -- promote an account manually (see the
-- "ADMIN ACCESS" note near the bottom) after it has signed up normally.
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  is_admin boolean not null default false
);

create table cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null references products(id),
  qty int not null check (qty > 0),
  unique (user_id, product_id)
);

create table wishlist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null references products(id),
  unique (user_id, product_id)
);

create table orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  status text not null default 'Processing',
  total numeric not null,
  name text not null,
  phone text not null,
  address text not null,
  payment_method text not null
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  product_id text not null references products(id),
  qty int not null,
  price_at_purchase numeric not null
);

-- Postgres doesn't auto-index FK columns (only PKs); these are read on every
-- RLS check for orders/order_items/product_images/product_reviews, so they
-- need an explicit index. (cart_items/wishlist_items don't need one here:
-- their existing `unique (user_id, product_id)` constraint already indexes
-- user_id as its leading column.)
create index orders_user_id_idx on orders(user_id);
create index order_items_order_id_idx on order_items(order_id);
create index product_images_product_id_idx on product_images(product_id);
create index product_reviews_product_id_idx on product_reviews(product_id);

-- ===================== AUTO-CREATE PROFILE ON SIGNUP =====================
-- The frontend passes { data: { name } } to supabase.auth.signUp(); this
-- trigger copies that into profiles the moment the auth.users row exists,
-- so there's no client-side race between "user created" and "profile created".

create function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ===================== ROW LEVEL SECURITY =====================
-- Everything is denied by default once RLS is enabled; each policy below is
-- an explicit exception. There is no admin UI in this app, so categories/
-- products get read-only policies (edit them from the dashboard if needed).

alter table categories enable row level security;
alter table products enable row level security;
alter table product_images enable row level security;
alter table product_reviews enable row level security;
alter table profiles enable row level security;
alter table cart_items enable row level security;
alter table wishlist_items enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;

create policy "public read categories" on categories for select using (true);
create policy "public read products" on products for select using (true);
create policy "public read product gallery" on product_images for select using (true);
create policy "public read reviews" on product_reviews for select using (true);

create policy "read own profile" on profiles for select using (auth.uid() = id);

create policy "manage own cart" on cart_items for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "manage own wishlist" on wishlist_items for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Review INSERT is gated to users who've actually bought this product on an
-- order that isn't Cancelled (see 0007_product_reviews.sql's header comment
-- for why Cancelled-only, not Delivered-only). UPDATE/DELETE are simple
-- owner checks -- a reviewer can edit or remove their own review any time.
create policy "verified purchaser insert review" on product_reviews for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from order_items oi
      join orders o on o.id = oi.order_id
      where oi.product_id = product_reviews.product_id
        and o.user_id = auth.uid()
        and o.status <> 'Cancelled'
    )
  );
create policy "manage own review" on product_reviews for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "delete own review" on product_reviews for delete
  using (auth.uid() = user_id);

create policy "read own orders" on orders for select using (auth.uid() = user_id);
create policy "insert own orders" on orders for insert with check (auth.uid() = user_id);

create policy "read own order items" on order_items for select
  using (exists (select 1 from orders o where o.id = order_items.order_id and o.user_id = auth.uid()));
create policy "insert own order items" on order_items for insert
  with check (exists (select 1 from orders o where o.id = order_items.order_id and o.user_id = auth.uid()));

-- Admin dashboard (admin/): additive policies, gated on profiles.is_admin.
-- In practice orders/order_items are only ever written by place_order()
-- below (SECURITY DEFINER, so it bypasses these entirely) -- these let an
-- admin browse every order and update its status from the dashboard.
create policy "admin manage products" on products for all
  using (exists (select 1 from profiles where id = auth.uid() and is_admin))
  with check (exists (select 1 from profiles where id = auth.uid() and is_admin));

create policy "admin manage categories" on categories for all
  using (exists (select 1 from profiles where id = auth.uid() and is_admin))
  with check (exists (select 1 from profiles where id = auth.uid() and is_admin));

create policy "admin manage product gallery" on product_images for all
  using (exists (select 1 from profiles where id = auth.uid() and is_admin))
  with check (exists (select 1 from profiles where id = auth.uid() and is_admin));

create policy "admin read all orders" on orders for select
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));
create policy "admin update orders" on orders for update
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));

create policy "admin read all order items" on order_items for select
  using (exists (select 1 from profiles where id = auth.uid() and is_admin));

-- Storage bucket for admin-uploaded product images (alongside the existing
-- paste-a-URL field). Public bucket since product photos are public-facing;
-- writes are gated to admins via the same profiles.is_admin pattern.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "admin manage product images" on storage.objects for all
  using (bucket_id = 'product-images' and exists (select 1 from profiles where id = auth.uid() and is_admin))
  with check (bucket_id = 'product-images' and exists (select 1 from profiles where id = auth.uid() and is_admin));

create policy "public read product images" on storage.objects for select
  using (bucket_id = 'product-images');

-- ===================== CHECKOUT: place_order() =====================
-- Turns a cart into a real order: validates stock, inserts the order + its
-- items at current price, decrements stock, and returns the new order_code.
-- SECURITY DEFINER so it can decrement products.stock (regular users have no
-- UPDATE grant on products); user_id is always auth.uid(), never trusted
-- from the caller, so this can't be used to place an order as someone else.
create or replace function place_order(
  items jsonb, -- [{"id": "product-id", "qty": 2}, ...]
  p_name text,
  p_phone text,
  p_address text,
  p_payment_method text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_order_id uuid;
  v_order_code text;
  v_total numeric := 0;
  v_item record;
  v_price numeric;
  v_stock int;
begin
  if v_user_id is null then
    raise exception 'Must be logged in to place an order';
  end if;
  if jsonb_array_length(items) = 0 then
    raise exception 'Cart is empty';
  end if;

  -- Validate stock up front so we fail before writing anything.
  for v_item in select (e->>'id') as id, (e->>'qty')::int as qty from jsonb_array_elements(items) e
  loop
    select price, stock into v_price, v_stock from products where id = v_item.id for update;
    if v_price is null then
      raise exception 'Product % no longer exists', v_item.id;
    end if;
    if v_stock < v_item.qty then
      raise exception 'Not enough stock for %: only % left', v_item.id, v_stock;
    end if;
    v_total := v_total + v_price * v_item.qty;
  end loop;

  v_order_code := 'WF-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into orders (order_code, user_id, total, name, phone, address, payment_method)
  values (v_order_code, v_user_id, v_total, p_name, p_phone, p_address, p_payment_method)
  returning id into v_order_id;

  for v_item in select (e->>'id') as id, (e->>'qty')::int as qty from jsonb_array_elements(items) e
  loop
    select price into v_price from products where id = v_item.id;
    insert into order_items (order_id, product_id, qty, price_at_purchase)
    values (v_order_id, v_item.id, v_item.qty, v_price);
    update products set stock = stock - v_item.qty where id = v_item.id;
  end loop;

  return v_order_code;
end;
$$;

grant execute on function place_order(jsonb, text, text, text, text) to authenticated;

-- ===================== REVIEWS: recompute_product_rating() =====================
-- Keeps products.rating/products.reviews in sync with real product_reviews
-- rows. Only fires on actual product_reviews mutations -- a product with no
-- reviews yet keeps its existing seeded rating/reviews values untouched.
create or replace function recompute_product_rating()
returns trigger as $$
declare
  v_product_id text := coalesce(new.product_id, old.product_id);
begin
  update products set
    rating = coalesce((select round(avg(rating)::numeric, 1) from product_reviews where product_id = v_product_id), rating),
    reviews = (select count(*) from product_reviews where product_id = v_product_id)
  where id = v_product_id;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_product_review_change
  after insert or update or delete on product_reviews
  for each row execute function recompute_product_rating();

-- ===================== ADMIN ACCESS =====================
-- There's no self-serve admin signup. Sign up a normal account through the
-- storefront first, find its id (Authentication -> Users in the Supabase
-- dashboard, or `select id from auth.users where email = '...'`), then run:
--   update profiles set is_admin = true where id = '<that uuid>';

-- ===================== SEED DATA =====================
-- WellFashion's clothing catalog: kurtha, sari, tops, winter wear, summer wear.

-- Categories (sort_order preserves the order used in index.html's banners/nav)
insert into categories (slug, label, icon, sort_order) values
  ('kurtha', 'Kurtha', '👚', 0),
  ('sari', 'Sari', '🥻', 1),
  ('tops', 'Tops', '👕', 2),
  ('winter-wear', 'Winter Wear', '🧥', 3),
  ('summer-wear', 'Summer Wear', '👗', 4);

-- Products
insert into products (id, name, price, old_price, category_slug, img, rating, reviews, flash, sold) values
  ('wf-cotton-printed-kurtha', 'Cotton Printed Kurtha', 1450, 1800, 'kurtha', 'assets/image/wf-cotton-printed-kurtha.svg', 4.6, 142, true, 62),
  ('wf-embroidered-silk-kurtha', 'Embroidered Silk Kurtha', 3200, NULL, 'kurtha', 'assets/image/wf-embroidered-silk-kurtha.svg', 4.7, 58, false, NULL),
  ('wf-anarkali-kurtha-set', 'Anarkali Kurtha Set', 4500, 5500, 'kurtha', 'assets/image/wf-anarkali-kurtha-set.svg', 4.8, 91, false, NULL),
  ('wf-chikankari-kurtha', 'Chikankari Kurtha', 2800, NULL, 'kurtha', 'assets/image/wf-chikankari-kurtha.svg', 4.6, 47, false, NULL),
  ('wf-straight-cut-kurtha', 'Straight-Cut Cotton Kurtha', 1200, NULL, 'kurtha', 'assets/image/wf-straight-cut-kurtha.svg', 4.4, 203, false, NULL),
  ('wf-designer-party-kurtha', 'Designer Party Kurtha', 3800, 4600, 'kurtha', 'assets/image/wf-designer-party-kurtha.svg', 4.8, 28, true, 28),
  ('wf-banarasi-silk-sari', 'Banarasi Silk Sari', 12500, 15000, 'sari', 'assets/image/wf-banarasi-silk-sari.svg', 4.9, 76, true, 19),
  ('wf-cotton-handloom-sari', 'Cotton Handloom Sari', 2600, NULL, 'sari', 'assets/image/wf-cotton-handloom-sari.svg', 4.5, 64, false, NULL),
  ('wf-georgette-printed-sari', 'Georgette Printed Sari', 3400, 4100, 'sari', 'assets/image/wf-georgette-printed-sari.svg', 4.6, 52, false, NULL),
  ('wf-chiffon-party-sari', 'Chiffon Party Sari', 4200, NULL, 'sari', 'assets/image/wf-chiffon-party-sari.svg', 4.7, 39, false, NULL),
  ('wf-linen-sari', 'Linen Sari', 3100, NULL, 'sari', 'assets/image/wf-linen-sari.svg', 4.5, 31, false, NULL),
  ('wf-bridal-silk-sari', 'Bridal Silk Sari', 18500, 22000, 'sari', 'assets/image/wf-bridal-silk-sari.svg', 4.9, 23, true, 11),
  ('wf-casual-cotton-top', 'Casual Cotton Top', 850, NULL, 'tops', 'assets/image/wf-casual-cotton-top.svg', 4.4, 188, false, NULL),
  ('wf-printed-blouse-top', 'Printed Blouse Top', 950, 1200, 'tops', 'assets/image/wf-printed-blouse-top.svg', 4.5, 97, false, NULL),
  ('wf-off-shoulder-top', 'Off-Shoulder Top', 1100, NULL, 'tops', 'assets/image/wf-off-shoulder-top.svg', 4.3, 73, false, NULL),
  ('wf-crop-top', 'Crop Top', 700, NULL, 'tops', 'assets/image/wf-crop-top.svg', 4.6, 265, true, 140),
  ('wf-formal-office-top', 'Formal Office Top', 1350, 1600, 'tops', 'assets/image/wf-formal-office-top.svg', 4.5, 54, false, NULL),
  ('wf-peplum-top', 'Peplum Top', 1250, NULL, 'tops', 'assets/image/wf-peplum-top.svg', 4.4, 41, false, NULL),
  ('wf-wool-cardigan', 'Wool Cardigan', 2600, 3200, 'winter-wear', 'assets/image/wf-wool-cardigan.svg', 4.6, 68, false, NULL),
  ('wf-fleece-jacket', 'Fleece Jacket', 2100, NULL, 'winter-wear', 'assets/image/wf-fleece-jacket.svg', 4.5, 55, false, NULL),
  ('wf-puffer-jacket', 'Puffer Jacket', 4500, 5500, 'winter-wear', 'assets/image/wf-puffer-jacket.svg', 4.7, 44, true, 34),
  ('wf-thermal-sweater', 'Thermal Sweater', 1800, NULL, 'winter-wear', 'assets/image/wf-thermal-sweater.svg', 4.4, 82, false, NULL),
  ('wf-wool-shawl', 'Wool Shawl / Wrap', 2200, 2700, 'winter-wear', 'assets/image/wf-wool-shawl.svg', 4.6, 37, false, NULL),
  ('wf-linen-sundress', 'Linen Sundress', 1900, NULL, 'summer-wear', 'assets/image/wf-linen-sundress.svg', 4.5, 49, false, NULL),
  ('wf-cotton-coord-set', 'Cotton Co-ord Set', 1650, 2000, 'summer-wear', 'assets/image/wf-cotton-coord-set.svg', 4.7, 61, true, 45),
  ('wf-sleeveless-maxi-dress', 'Sleeveless Maxi Dress', 2100, NULL, 'summer-wear', 'assets/image/wf-sleeveless-maxi-dress.svg', 4.5, 38, false, NULL),
  ('wf-breathable-shorts-set', 'Breathable Shorts Set', 1200, 1450, 'summer-wear', 'assets/image/wf-breathable-shorts-set.svg', 4.4, 29, false, NULL),
  ('wf-flowy-palazzo-set', 'Flowy Palazzo Set', 1550, NULL, 'summer-wear', 'assets/image/wf-flowy-palazzo-set.svg', 4.3, 22, false, NULL);
