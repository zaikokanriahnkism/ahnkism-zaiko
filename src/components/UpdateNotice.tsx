'use client'

import { useEffect, useState } from 'react'

const CURRENT = process.env.NEXT_PUBLIC_APP_VERSION ?? 'dev'

// 新しい版が公開されたら、画面の下に「新しい版があります。押して更新」を出す
// 1分ごとと、画面に戻ってきたときに確かめる（開きっぱなしのタブやスマホでも新しい画面に切り替えやすくする）
export default function UpdateNotice() {
  const [hasUpdate, setHasUpdate] = useState(false)

  useEffect(() => {
    if (CURRENT === 'dev') return
    let stopped = false
    const check = async () => {
      if (stopped || document.visibilityState !== 'visible') return
      try {
        const response = await fetch(`/api/version?t=${Date.now()}`, { cache: 'no-store' })
        if (!response.ok) return
        const { version } = await response.json() as { version?: string }
        if (version && version !== 'dev' && version !== CURRENT) setHasUpdate(true)
      } catch {}
    }
    const timer = window.setInterval(() => void check(), 60_000)
    const onVisible = () => { if (document.visibilityState === 'visible') void check() }
    document.addEventListener('visibilitychange', onVisible)
    void check()
    return () => { stopped = true; window.clearInterval(timer); document.removeEventListener('visibilitychange', onVisible) }
  }, [])

  if (!hasUpdate) return null
  return (
    <button onClick={() => window.location.reload()}
      className="fixed inset-x-3 bottom-3 z-[60] mx-auto max-w-md rounded-2xl bg-blue-600 px-4 py-3 text-center text-sm font-bold text-white shadow-xl">
      新しい版があります。押して更新
    </button>
  )
}
