# 構成と本番との差

```text
PC ── SSH:22 ── App1 / App2 / App3 / Benchmark
   └─ HTTPS:443 ── App1 / App2 / App3
Benchmark ── HTTPS:443 ＋ DNS:UDP/TCP 53 ── App1 / App2 / App3
App1 / App2 / App3 ←── 相互通信 ──→ App1 / App2 / App3
```

競技用3台は公式ISUCON13 AMI、c5.large、各gp3 40GiBです。Nginx・ISUPIPEアプリ・MySQL・PowerDNSが入り、最初はApp1を名前解決・アプリの負荷先とします。3台へ自動分散する設定は作りません。DB・DNSレコード・リバースプロキシ等は改善方針に合わせて設定します。

競技用グループ内は相互通信を許可します。ベンチからは競技用へのHTTPSとDNSだけを許可し、DNSをインターネットには公開しません。PCからのSSHと競技用HTTPSはMyIpCidrだけに制限します。ISUCON14の決済モック用12345は不要なので開放しません。

ベンチ用も同じ公式AMIを使い、同梱の `/home/isucon/bench_linux_amd64` を実行します。競技用アプリとは独立したホストのため負荷生成が競技用のCPUを消費しません。不要な競技用サービスはベンチVMで停止します。

本番のベンチはECS Fargate（公式記載8 vCPU / 8GB）です。練習環境ではSSHで扱えるc5.2xlarge（8 vCPU / 16GiB）へ置き換え、ベンチ用ディスクも40GiBとしています。実行基盤・帯域・メモリ・スコアは完全一致しません。公式の動画・サムネイル配信は廃止されています。

既存VPC・サブネット・Internet Gatewayを利用します。新規VPC、NAT Gateway、Elastic IP、ロードバランサーは作りません。AMI同梱の初回設定がDNSレコード用アドレスを公開IPにする場合があるため、ベンチ前にプライベートIPへ修正します。

参照：[公式README](https://github.com/isucon/isucon13)。確認ソースは `8f6afdc3603f0c661368de4659a7240862f59623`。AMIの公開状態は別途AWS上で確認が必要です。
