-- 先行予約：商品ごとの割引に「消費税分オフ」（税込価格 ÷1.1。1円未満は四捨五入）を追加する。機械類などで使う
do $$
declare
  v_name text;
begin
  select conname into v_name from pg_constraint
  where conrelid = 'public.presale_items'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%discount_type%';
  if v_name is not null then execute format('alter table public.presale_items drop constraint %I', v_name); end if;
end;
$$;
alter table public.presale_items add constraint presale_items_discount_type_check check (discount_type in ('percent', 'yen', 'tax_off'));

create or replace function public.presale_price_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_campaign bigint;
  v_count integer;
  v_percent numeric;
begin
  select campaign_id into v_campaign from public.presale_orders where id = p_order_id;

  select coalesce(sum(l.quantity), 0) into v_count
  from public.presale_order_lines l
  join public.presale_items i on i.campaign_id = v_campaign and i.product_id = l.product_id
  where l.order_id = p_order_id and not i.bulk_excluded;

  select percent into v_percent from public.presale_bulk_tiers
  where campaign_id = v_campaign and min_qty <= v_count order by min_qty desc limit 1;

  -- 優先順：その行だけの割引 → まとめ買い（対象外の商品は除く） → 商品ごとの割引
  update public.presale_order_lines l
  set regular_price = round(p.sale_price * 1.1),
      unit_price = case
        when p.sale_price is null then null
        when l.line_discount_type = 'percent' then round(round(p.sale_price * 1.1) * (1 - l.line_discount_value / 100))
        when l.line_discount_type = 'yen' then greatest(0, round(p.sale_price * 1.1) - l.line_discount_value)
        when v_percent is not null and not i.bulk_excluded then round(round(p.sale_price * 1.1) * (1 - v_percent / 100))
        when i.discount_type = 'percent' then round(round(p.sale_price * 1.1) * (1 - i.discount_value / 100))
        when i.discount_type = 'tax_off' then round(round(p.sale_price * 1.1) / 1.1)
        else greatest(0, round(p.sale_price * 1.1) - i.discount_value)
      end
  from public.products p, public.presale_items i
  where l.order_id = p_order_id and p.id = l.product_id and i.campaign_id = v_campaign and i.product_id = l.product_id;

  update public.presale_orders o
  set total_qty = v_count,
      applied_percent = v_percent,
      total_amount = coalesce((select sum(coalesce(l.unit_price, 0) * l.quantity) from public.presale_order_lines l where l.order_id = o.id), 0),
      updated_at = now()
  where o.id = p_order_id;
end;
$$;
