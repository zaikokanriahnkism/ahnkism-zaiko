-- 先行予約：予約の「用意済み」チェック（予約ごとに1回押す）。中身は商品ごとに記録する
-- ・予約を修正しても、すでに用意した商品は用意済みのまま（画面から prepared を送る。追加した商品・数を増やした商品は未用意になる）
-- ・一部だけ用意済みのときは、画面に「一部用意済み（未用意：〇〇）」と出る
alter table public.presale_order_lines add column if not exists prepared boolean not null default false;

-- 予約の商品をまとめて「用意済み」にする／外す
create or replace function public.set_presale_order_prepared(p_store_id bigint, p_token text, p_pin text, p_order_id uuid, p_value boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform public.presale_authorize(p_store_id, p_token, p_pin);
  if not exists (select 1 from public.presale_orders where id = p_order_id and store_id = p_store_id) then
    raise exception '予約が見つかりません';
  end if;
  update public.presale_order_lines set prepared = p_value where order_id = p_order_id;
end;
$$;
grant execute on function public.set_presale_order_prepared(bigint, text, text, uuid, boolean) to anon, authenticated;

do $$
declare
  v_def text;
begin
  -- 予約の保存：画面から送られた prepared を残す
  v_def := pg_get_functiondef('public.save_presale_order(bigint,text,text,jsonb)'::regprocedure);
  if position('needs_order, line_no)' in v_def) = 0 or position('coalesce((t.l->>''needs_order'')::boolean, false), t.n::integer' in v_def) = 0 then
    raise exception 'save_presale_order の形が想定と違います';
  end if;
  v_def := replace(v_def, 'needs_order, line_no)', 'needs_order, line_no, prepared)');
  v_def := replace(v_def, 'coalesce((t.l->>''needs_order'')::boolean, false), t.n::integer',
                          'coalesce((t.l->>''needs_order'')::boolean, false), t.n::integer, coalesce((t.l->>''prepared'')::boolean, false)');
  execute v_def;

  -- 見るだけページにも「用意済み」を返す
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname = 'presale_view_data';
  if position('''reserved_qty'', l.reserved_qty) order by' in v_def) = 0 then
    raise exception 'presale_view_data の形が想定と違います';
  end if;
  execute replace(v_def, '''reserved_qty'', l.reserved_qty) order by', '''reserved_qty'', l.reserved_qty, ''prepared'', l.prepared) order by');
end;
$$;
