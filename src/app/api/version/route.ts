// いま公開されている版を返す。開いたままの画面が、自分の版と比べて古ければ「更新」の案内を出す
export async function GET() {
  return Response.json(
    { version: process.env.VERCEL_GIT_COMMIT_SHA ?? 'dev' },
    { headers: { 'Cache-Control': 'no-store' } },
  )
}
