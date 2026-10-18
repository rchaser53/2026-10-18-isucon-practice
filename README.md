# ISUCON13 練習環境：CloudFormationでEC2を1台起動する

ISUCON13の[公開AMI](https://github.com/isucon/isucon13)を使って、AWSにEC2インスタンスを**1台だけ**起動する学習用構成です。運営の3台構成や外部ベンチマーカーを完全再現するものではありません。

- [構成と仕組み](docs/architecture.md)
- [構築・SSH接続手順](docs/setup.md)
- [課金と削除手順](docs/cleanup.md)
- [CloudFormationテンプレート](cloudformation/isucon13-one-ec2.yaml)

## 構成

```text
自分のPC ── SSH:22（自分のIPv4アドレスのみ）── EC2 × 1
                                            ├─ ISUCON13公開AMI
                                            ├─ Nginx / Webアプリ / MySQL
                                            └─ EBS gp3 30GiB

既存のVPCとインターネット接続可能なサブネットを利用
```

| 項目 | 設定 |
| --- | --- |
| リージョン | 東京 ap-northeast-1 |
| AMI | ami-041289d910c114864（利用可否は要確認） |
| インスタンス | t3.medium（2 vCPU / 4GiB、CPUクレジット standard） |
| 比較用 | c5.largeに切り替え可能 |
| EBS | gp3 30GiB、暗号化、インスタンス終了時に削除 |
| 公開ポート | SSH 22のみ。接続元IPを /32 で制限 |
| 作らないリソース | NAT Gateway、Elastic IP、新規VPC、ベンチマーカー |

> [!WARNING]
> **AWSで費用が発生します。** EC2、EBS、パブリックIPv4等は課金対象です。CloudFormationスタックを削除して関連リソースが消えたことを確認してください。AWS Budgetsによる予算アラートも推奨します（課金は自動停止されません）。

> [!NOTE]
> このテンプレートは独自の学習用構成で、公式のCloudFormationテンプレートではありません。AWSアカウント上での起動検証は未実施です。

公式資料：[ISUCON13](https://github.com/isucon/isucon13) / [CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)
