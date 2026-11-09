-- 先行予約：店販用の商品が「選べる状態」（店販用・取扱中・価格あり）になったら、受付中の先行予約の対象に自動で入れる
-- ・新しく追加したとき、または価格が入った／店販用になった／取扱を再開したときだけ（対象から外した商品の価格を直しても戻さない）
-- ・臨時の商品（presale_campaign_id あり）は予約の画面で追加したときに入るので対象外
-- ・美容機器（ReFa・ドライヤー・パワーストレートで始まる名前）は、まとめ買い対象外で入れる
create or replace function public.presale_auto_add_retail()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.product_type <> 'retail' or not new.is_active or new.sale_price is null or new.presale_campaign_id is not null then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.product_type = 'retail' and old.is_active and old.sale_price is not null then
    return new;
  end if;
  insert into public.presale_items (campaign_id, product_id, discount_type, discount_value, bulk_excluded)
  select c.id, new.id, 'percent', 0, new.name ~ '^(ReFa|ドライヤー|パワーストレート)'
  from public.presale_campaigns c
  where c.is_active
  on conflict (campaign_id, product_id) do nothing;
  return new;
end;
$$;

drop trigger if exists presale_auto_add_retail on public.products;
create trigger presale_auto_add_retail
after insert or update of product_type, is_active, sale_price on public.products
for each row execute function public.presale_auto_add_retail();
