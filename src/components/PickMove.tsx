'use client'

import { useCallback, useState } from 'react'

// 並べ替え：動かしたい物にチェック →「ここへ」で、その上にまとめて移す（離れた場所にも1回で動かせる）
// target が null のときは一番下へ。選んだ物どうしの順番はそのまま
export function moveBefore<K>(list: K[], picked: Set<K>, target: K | null): K[] {
  const moving = list.filter((key) => picked.has(key))
  const rest = list.filter((key) => !picked.has(key))
  const index = target === null ? rest.length : rest.indexOf(target)
  if (index < 0) return list
  return [...rest.slice(0, index), ...moving, ...rest.slice(index)]
}

export function usePick<K>() {
  const [picked, setPicked] = useState<Set<K>>(new Set())
  const toggle = useCallback((key: K) => setPicked((previous) => {
    const next = new Set(previous)
    if (next.has(key)) next.delete(key)
    else next.add(key)
    return next
  }), [])
  const clear = useCallback(() => setPicked(new Set()), [])
  return { picked, toggle, clear }
}

export function PickToggle({ checked, onChange, label = '選ぶ' }: { checked: boolean; onChange: () => void; label?: string }) {
  return (
    <label className={`flex shrink-0 cursor-pointer items-center gap-1 rounded px-1.5 py-1 text-[11px] ${checked ? 'bg-amber-200 font-bold text-amber-900' : 'bg-gray-100 text-gray-500'}`}>
      <input type="checkbox" checked={checked} onChange={onChange} className="h-4 w-4 accent-amber-500" />
      {label}
    </label>
  )
}

export function PlaceHere({ onClick }: { onClick: () => void }) {
  return (
    <button onClick={onClick} className="shrink-0 rounded bg-amber-500 px-2 py-1 text-[11px] font-bold text-white">ここへ</button>
  )
}

// 選んでいる間だけ出す案内。画面の下に固定して、スクロールしても見えるようにする
export function PickBar({ count, onEnd, onClear }: { count: number; onEnd: () => void; onClear: () => void }) {
  if (count === 0) return null
  return (
    <div className="fixed inset-x-0 bottom-0 z-40 border-t border-amber-300 bg-amber-50 px-4 py-2 shadow-lg">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center gap-2 text-sm">
        <span className="font-bold text-amber-900">{count}件を選んでいます</span>
        <span className="text-xs text-amber-800">移したい場所の「ここへ」を押すと、その上に入ります</span>
        <span className="flex-1" />
        <button onClick={onEnd} className="rounded-lg border border-amber-400 bg-white px-3 py-1.5 text-xs font-bold text-amber-800">一番下へ</button>
        <button onClick={onClear} className="rounded-lg bg-white px-3 py-1.5 text-xs text-gray-600">選ぶのをやめる</button>
      </div>
    </div>
  )
}
