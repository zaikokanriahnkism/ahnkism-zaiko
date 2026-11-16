-- 月次レポート：その他の経費の費目ごとに「店販原価に足して見る」かどうか（その他 店販）
-- 店舗別の表に「店販原価＋経費」とその率を出す。もとの店販原価・店販原価率はそのまま
alter table public.expense_categories add column if not exists include_in_retail boolean not null default false;
update public.expense_categories set include_in_retail = true where regexp_replace(name, '\s', '', 'g') = 'その他店販';
