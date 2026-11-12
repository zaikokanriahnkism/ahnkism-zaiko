-- 月次レポート：その他の経費の費目ごとに「材料費に足して見る」かどうか（修理代・その他 業務）
-- 店舗別の表に「材料費（経費込み）」とその率を出す。もとの材料費・材料費率はそのまま
alter table public.expense_categories add column if not exists include_in_material boolean not null default false;
update public.expense_categories set include_in_material = true
where name = '修理代' or regexp_replace(name, '\s', '', 'g') = 'その他業務';
