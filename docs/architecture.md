# 構成と本番との差

```text
PC ── SSH ── App1 / App2 / App3 / Benchmark
   └─ HTTPS ── App1 / App2 / App3

Benchmark ── HTTPS:443（プライベートIP）── App1（初期の負荷先）
App1 / App2 / App3 ── TCP:12345 ── Benchmark（決済モック）
App1 / App2 / App3 ←── 相互通信 ──→ App1 / App2 / App3
```

競技用3台は公式AMIから起動するc5.large、各gp3 20GiBです。各台にNginx・Webアプリ・MySQLが入り、最初はApp1をベンチ対象にします。3台に自動で分散されるわけではありません。DBの待受アドレス・接続設定・リバースプロキシ等は改善方針に合わせて変更します。

競技用セキュリティグループ内の相互通信を許可し、ベンチ用から競技用への443と、競技用からベンチ用への12345を許可します。SSHとPCからのHTTPSはMyIpCidrだけに制限します。送信はデフォルトで許可されます。SSH鍵をサーバー間でコピーする必要はありません。

ベンチ用はUbuntu 24.04の別AMIで起動し、公式ソースからベンチをビルドします。競技用AMIにベンチが入っていることは前提にしません。本番のECS FargateからEC2へ置き換えるため、8 vCPUは同じでもメモリは16GiBとなります。ネットワーク帯域・配置・性能は本番と一致しません。

既存VPC・サブネット・Internet Gatewayを使い、新規VPC、NAT Gateway、Elastic IP、ロードバランサーは作りません。ベンチや依存パッケージの取得にはインターネット接続が必要です。

参照：[公式README](https://github.com/isucon/isucon14)、[EC2仕様](https://docs.aws.amazon.com/ec2/latest/instancetypes/co.html)。確認した公式ソースは `53f8b627e040c30ebec600457c6c97da008b84b0` です。
