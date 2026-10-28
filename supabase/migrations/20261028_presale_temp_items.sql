-- 先行予約：予約の画面から「臨時の商品」（一覧にない、先行のときだけ出る商品）を追加できる
-- ・商品名と税込の金額だけで登録する。入れた企画の中だけで、全店舗の商品選びに出る（普段の商品一覧・在庫には出さない）
-- ・同じ名前の商品がその企画にすでにあれば、新しく作らずにそれを使う（表記ゆれで数が分かれないように）
-- ・在庫を持たない商品なので、お渡ししても在庫は動かさない
-- ・本部が「通常の商品にする」と、presale_campaign_id を外して普段の商品になる
alter table public.products add column if not exists presale_campaign_id bigint;
comment on column public.products.presale_campaign_id is '臨時の商品（先行予約の予約画面で追加）を入れた企画。null＝通常の商品';
create index if not exists products_presale_campaign_id_idx on public.products (presale_campaign_id) where presale_campaign_id is not null;

create or replace function public.add_presale_temp_item(
  p_store_id bigint, p_token text, p_pin text, p_campaign_id bigint, p_name text, p_price integer, p_bulk_excluded boolean
)
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_name text := trim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_key text;
  v_id bigint;
  v_category bigint;
begin
  perform public.presale_authorize(p_store_id, p_token, p_pin);
  if not exists (select 1 from public.presale_campaigns where id = p_campaign_id and is_active) then
    raise exception '企画が見つかりません';
  end if;
  if v_name = '' then raise exception '商品名を入力してください'; end if;
  if length(v_name) > 100 then raise exception '商品名が長すぎます'; end if;
  if p_price is null or p_price < 0 then raise exception '金額（税込）を入力してください'; end if;

  -- 同じ名前（全角半角・大文字小文字・空白の違いは同じとみなす）の商品がこの企画にあれば、それを使う
  v_key := lower(regexp_replace(normalize(v_name, NFKC), '\s', '', 'g'));
  select p.id into v_id
  from public.presale_items i join public.products p on p.id = i.product_id
  where i.campaign_id = p_campaign_id
    and lower(regexp_replace(normalize(coalesce(p.brand, '') || p.name, NFKC), '\s', '', 'g')) = v_key
  order by p.presale_campaign_id nulls first, p.id
  limit 1;
  if v_id is not null then return v_id; end if;

  select id into v_category from public.categories where name = '店販' order by id limit 1;
  insert into public.products (category_id, name, product_type, sale_price, is_active, presale_campaign_id)
  values (v_category, v_name, 'retail', round(p_price / 1.1), true, p_campaign_id)
  returning id into v_id;
  insert into public.presale_items (campaign_id, product_id, discount_type, discount_value, bulk_excluded)
  values (p_campaign_id, v_id, 'percent', 0, coalesce(p_bulk_excluded, false));
  return v_id;
end;
$$;
grant execute on function public.add_presale_temp_item(bigint, text, text, bigint, text, integer, boolean) to anon, authenticated;

-- お渡し：臨時の商品は在庫を持たないので在庫を動かさない（それ以外は 20261022_presale_partial_delivery と同じ）
create or replace function public.set_presale_order_delivered(
  p_store_id bigint, p_token text, p_pin text, p_order_id uuid, p_delivered boolean, p_quantities jsonb default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_order public.presale_orders;
  v_line public.presale_order_lines;
  v_movement uuid;
  v_test boolean;
  v_qty integer;
  v_changed boolean := false;
begin
  perform public.presale_authorize(p_store_id, p_token, p_pin);
  select * into v_order from public.presale_orders where id = p_order_id for update;
  if not found or v_order.store_id <> p_store_id then
    raise exception '予約が見つかりません';
  end if;
  if v_order.cancelled_at is not null then
    raise exception 'キャンセル済みの予約です';
  end if;
  select is_test into v_test from public.presale_campaigns where id = v_order.campaign_id;

  if p_delivered and v_order.delivered_at is null then
    if p_quantities is not null then
      for v_line in select * from public.presale_order_lines where order_id = p_order_id loop
        v_qty := coalesce((p_quantities->>v_line.id::text)::integer, v_line.quantity);
        if v_qty < 0 or v_qty > v_line.quantity then
          raise exception '渡す数は0〜予約の数（%）の間で入れてください', v_line.quantity;
        end if;
        if v_qty <> v_line.quantity then
          update public.presale_order_lines set reserved_qty = quantity, quantity = v_qty where id = v_line.id;
          v_changed := true;
        end if;
      end loop;
      if not exists (select 1 from public.presale_order_lines where order_id = p_order_id and quantity > 0) then
        raise exception '渡す数がすべて0です。渡さない場合は予約をキャンセルにしてください';
      end if;
      if v_changed then
        perform public.presale_price_order(p_order_id);
      end if;
    end if;
    if not coalesce(v_test, false) then
      for v_line in select l.* from public.presale_order_lines l join public.products p on p.id = l.product_id
                    where l.order_id = p_order_id and l.quantity > 0 and p.presale_campaign_id is null loop
        insert into public.inventory_movements (store_id, product_id, occurred_on, quantity, movement_type, note, created_by)
        values (v_order.store_id, v_line.product_id, (now() at time zone 'Asia/Tokyo')::date, -v_line.quantity, 'retail_sale',
                '先行予約お渡し ' || v_order.id, auth.uid())
        returning id into v_movement;
        update public.presale_order_lines set delivered_movement_id = v_movement where id = v_line.id;
      end loop;
    end if;
    update public.presale_orders set delivered_at = now(), updated_at = now() where id = p_order_id;
  elsif not p_delivered and v_order.delivered_at is not null then
    delete from public.inventory_movements m
    using public.presale_order_lines l
    where l.order_id = p_order_id and m.id = l.delivered_movement_id;
    update public.presale_order_lines set delivered_movement_id = null where order_id = p_order_id;
    if exists (select 1 from public.presale_order_lines where order_id = p_order_id and reserved_qty is not null) then
      update public.presale_order_lines set quantity = reserved_qty, reserved_qty = null where order_id = p_order_id and reserved_qty is not null;
      perform public.presale_price_order(p_order_id);
    end if;
    update public.presale_orders set delivered_at = null, updated_at = now() where id = p_order_id;
  end if;
end;
$$;
grant execute on function public.set_presale_order_delivered(bigint, text, text, uuid, boolean, jsonb) to anon, authenticated;
