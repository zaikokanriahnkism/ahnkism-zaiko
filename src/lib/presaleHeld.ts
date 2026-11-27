import { supabase } from '@/lib/supabase'
import { fetchAll } from '@/lib/fetchAll'
import { JOINT_ORDER, jointStoreIds } from '@/lib/presale'

// 受付中の先行予約で取り置いている数（店舗ID_商品ID → 数）。お試しの企画は除く
// 取り置き中 ＝ 先行分 − お渡し済み。ただし、まだ渡していない予約の数まで（当日キャンセル分は外れる）
// まとめて発注する商品（Aujua）は、nit の予約も LABO の取り置きとして数える
export async function loadPresaleHeld(stores: { id: number; name: string }[], dealerByProduct: Map<number, string | null>) {
  const held = new Map<string, number>()
  const { data: activeCampaigns } = await supabase.from('presale_campaigns').select('id').eq('is_active', true).eq('is_test', false)
  const campaignIds = (activeCampaigns ?? []).map((row) => row.id as number)
  if (campaignIds.length === 0) return held
  const [allocationResult, lineResult] = await Promise.all([
    supabase.from('presale_allocations').select('store_id, product_id, allocated_qty').in('campaign_id', campaignIds),
    fetchAll((start, end) => supabase.from('presale_order_lines')
      .select('id, product_id, quantity, presale_orders!inner(store_id, campaign_id, delivered_at, cancelled_at)')
      .in('presale_orders.campaign_id', campaignIds)
      .is('presale_orders.cancelled_at', null).order('id').range(start, end)),
  ])
  const joint = jointStoreIds(stores)
  const holdStore = (storeId: number, productId: number) =>
    joint && dealerByProduct.get(productId) === JOINT_ORDER.dealer && joint.includes(storeId) ? joint[0] : storeId
  const allocated = new Map<string, number>()
  const delivered = new Map<string, number>()
  const open = new Map<string, number>()
  ;(allocationResult.data ?? []).forEach((row) => {
    const key = `${holdStore(row.store_id, row.product_id)}_${row.product_id}`
    allocated.set(key, (allocated.get(key) ?? 0) + row.allocated_qty)
  })
  ;(lineResult.data ?? []).forEach((row) => {
    const order = Array.isArray(row.presale_orders) ? row.presale_orders[0] : row.presale_orders
    const key = `${holdStore(order.store_id, row.product_id)}_${row.product_id}`
    const target = order.delivered_at ? delivered : open
    target.set(key, (target.get(key) ?? 0) + row.quantity)
  })
  allocated.forEach((value, key) => {
    held.set(key, Math.max(0, Math.min(value - (delivered.get(key) ?? 0), open.get(key) ?? 0)))
  })
  return held
}
