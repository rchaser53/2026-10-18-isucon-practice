# ISUCON13 練習環境：競技用3台＋ベンチ用1台

[公式ISUCON13 AMI](https://github.com/isucon/isucon13)を使用するCloudFormation構成です。東京リージョンに競技用3台と独立したベンチ用1台を作成します。

| 項目 | 設定 |
| --- | --- |
| リージョン | ap-northeast-1（東京のみ） |
| AMI（4台共通） | 公式掲載 `ami-041289d910c114864`。利用可能性の事前確認が必要 |
| 競技用VM | c5.large × 3（各2 vCPU / 4GiB） |
| 競技用ディスク | 各EBS gp3 40GiB |
| ベンチ用VM | c5.2xlarge × 1（8 vCPU / 16GiB）、gp3 40GiB |
| ネットワーク | 既存VPCの同一パブリックサブネット。負荷はプライベートIP経由 |
| 外部公開 | 自分のIPv4 /32からSSH、競技用へのHTTPS |

**AMI IDは公式READMEの掲載値であり、現在の利用可否を保証しません。** ISUCON14で発生したものと同様に、共有終了時には起動できません。必ず[AMI確認手順](docs/setup.md#1-amiの利用可否を最初に確認)で確認し、利用不可なら公式Packerで自作したISUCON13 AMIを `AmiId` に指定してください。汎用Ubuntu AMIでは代替できません。

競技用の台数・種類・ディスク容量はISUCON13本番に合わせています。ベンチは本番のECS Fargate（公式記載8 vCPU / 8GB）をEC2（8 vCPU / 16GiB）に置き換えます。スコア・メモリ・ネットワークは完全一致しません。3台への負荷分散やDB分離は自分で設定します。

- [構成と本番との差](docs/architecture.md)
- [AMI確認・構築・ベンチ実行](docs/setup.md)
- [Macからの計測・改善](docs/work-performance.md)
- [課金と削除](docs/cleanup.md)
- [CloudFormationテンプレート](cloudformation/isucon13-practice.yaml)

EC2 4台、EBS合計160GiB、パブリックIPv4 4個などに課金されます。既存スタックを直接更新せず新規作成し、必要なコード・データを退避してから旧スタックを削除してください。独自の練習用構成であり、AWS上でのAMI参照・起動・ベンチ実行は未検証です。
