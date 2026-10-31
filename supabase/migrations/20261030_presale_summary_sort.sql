-- 先行予約「集計・先行分の在庫」の並び（本部が「選ぶ → ここへ」で決める）。企画をまたいで同じ並びを使う
-- ・商品は発注先ごとにまとめて出し、発注先の順番と、発注先の中の商品の順番を覚えておく
create table if not exists public.presale_summary_sort (
  product_id bigint primary key references public.products(id) on delete cascade,
  sort_order integer not null
);
create table if not exists public.presale_summary_dealer_sort (
  dealer text primary key,
  sort_order integer not null
);
alter table public.presale_summary_sort enable row level security;
alter table public.presale_summary_dealer_sort enable row level security;
drop policy if exists presale_summary_sort_hq_all on public.presale_summary_sort;
create policy presale_summary_sort_hq_all on public.presale_summary_sort for all
  using (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'hq'))
  with check (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'hq'));
drop policy if exists presale_summary_dealer_sort_hq_all on public.presale_summary_dealer_sort;
create policy presale_summary_dealer_sort_hq_all on public.presale_summary_dealer_sort for all
  using (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'hq'))
  with check (exists (select 1 from public.user_profiles p where p.user_id = auth.uid() and p.role = 'hq'));
