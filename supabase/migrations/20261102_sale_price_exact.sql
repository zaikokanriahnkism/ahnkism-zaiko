-- 販売価格：税込で入れた金額がそのまま出るように、税抜の販売価格を小数まで保存する
-- （整数だと 12600円 → 税抜11455円 → 税込12601円 のように1円ずれる金額がある）
alter table public.products alter column sale_price type numeric using sale_price::numeric;
comment on column public.products.sale_price is '販売価格（税抜・円）。税込で入れた金額は ÷1.1 の小数まで残す';

-- 臨時の商品も税込の金額 ÷1.1 をそのまま保存する
do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.add_presale_temp_item(bigint,text,text,bigint,text,integer,boolean)'::regprocedure) into v_def;
  if position('round(p_price / 1.1)' in v_def) = 0 then
    raise exception 'add_presale_temp_item の形が想定と違います';
  end if;
  execute replace(v_def, 'round(p_price / 1.1)', 'p_price / 1.1');
end;
$$;

-- 1円ずれていた臨時の商品（リファハートコームアイロン シルバー：12600円）を直し、入っている予約の金額を計算し直す
update public.products set sale_price = 12600 / 1.1 where id = 977 and sale_price = 11455;
select public.presale_price_order(l.order_id) from (select distinct order_id from public.presale_order_lines where product_id = 977) l;
