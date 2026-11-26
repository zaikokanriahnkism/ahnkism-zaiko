-- 先行予約：店舗の予約ページの「商品ごとの予約数」を、本部の「集計・先行分の在庫」と同じ順番で出すための情報を足す
-- ・商品：dealer（発注先）、summary_sort（集計の表で並べた順）、base_store_rank / base_input_order（最初の店舗にある在庫入力の順）
-- ・dealer_sort：集計の表の発注先の順
do $$
declare
  v_def text;
  v_old text := '''input_order'', (select sp.sort_order from public.store_products sp where sp.store_id = v_store and sp.product_id = p.id)))';
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname = 'presale_portal_data';
  if position(v_old in v_def) = 0 or position('''tiers'', coalesce(' in v_def) = 0 then
    raise exception 'presale_portal_data の形が想定と違います';
  end if;
  v_def := replace(v_def, v_old,
    '''input_order'', (select sp.sort_order from public.store_products sp where sp.store_id = v_store and sp.product_id = p.id),'
    || ' ''dealer'', p.dealer,'
    || ' ''summary_sort'', (select ss.sort_order from public.presale_summary_sort ss where ss.product_id = p.id),'
    || ' ''base_store_rank'', (select st.sort_order from public.store_products sp join public.stores st on st.id = sp.store_id where sp.product_id = p.id and sp.is_active order by st.sort_order, st.id limit 1),'
    || ' ''base_input_order'', (select sp.sort_order from public.store_products sp join public.stores st on st.id = sp.store_id where sp.product_id = p.id and sp.is_active order by st.sort_order, st.id limit 1)))');
  v_def := replace(v_def, '''tiers'', coalesce(',
    '''dealer_sort'', coalesce((select jsonb_agg(jsonb_build_object(''dealer'', d.dealer, ''sort_order'', d.sort_order)) from public.presale_summary_dealer_sort d), ''[]''::jsonb),'
    || ' ''tiers'', coalesce(');
  execute v_def;
end;
$$;
