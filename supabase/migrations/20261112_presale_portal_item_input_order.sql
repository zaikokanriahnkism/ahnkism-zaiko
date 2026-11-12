-- 先行予約：店舗の予約ページの「商品を選ぶ」で、並びを決めていない商品は在庫入力と同じ並び（カテゴリの順 → 在庫入力の順）で出す
-- presale_portal_data の商品に category_order（カテゴリの順）と input_order（その店舗の在庫入力の順）を足す
do $$
declare
  v_def text;
  v_old text := '''brand'', p.brand, ''name'', p.name, ''sale_price'', p.sale_price))';
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname = 'presale_portal_data';
  if position(v_old in v_def) = 0 then
    raise exception 'presale_portal_data の形が想定と違います';
  end if;
  execute replace(v_def, v_old,
    '''brand'', p.brand, ''name'', p.name, ''sale_price'', p.sale_price,'
    || ' ''category_order'', (select cg.sort_order from public.categories cg where cg.id = p.category_id),'
    || ' ''input_order'', (select sp.sort_order from public.store_products sp where sp.store_id = v_store and sp.product_id = p.id)))');
end;
$$;
