import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // 画面に埋め込む版（公開したときのコミット）。新しい版が出たら「更新」の案内を出すために使う
  env: {
    NEXT_PUBLIC_APP_VERSION: process.env.VERCEL_GIT_COMMIT_SHA ?? "dev",
  },
};

export default nextConfig;
