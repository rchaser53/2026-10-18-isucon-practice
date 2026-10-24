# ISUCON14 練習環境：競技用3台＋ベンチ用1台

[公式ISUCON14 AMI](https://github.com/isucon/isucon14)を使い、CloudFormationで東京リージョンに競技用EC2を3台、独立したベンチ用EC2を1台作成します。

2026-10-24確認：最新開催の[ISUCON2026は10月31日予定](https://isucon.net/archives/59917350.html)です。公開済みの公式問題・AMIで練習するためISUCON14を採用します。ISUCON2026の競技環境を再現するものではありません。

| 項目 | 設定 |
| --- | --- |
| リージョン | ap-northeast-1（東京のみ） |
| 競技用AMI | 公式 `ami-0e334c50145a3ee41`（AmiIdで変更可能） |
| 競技用VM | c5.large × 3（各2 vCPU / 4GiB） |
| 競技用ディスク | 各EBS gp3 20GiB、暗号化、終了時削除 |
| ベンチ用VM | c5.2xlarge × 1（8 vCPU / 16GiB）、gp3 30GiB |
| ベンチ用OS | Canonical公式Ubuntu 24.04 amd64、SSM公開パラメータから取得 |
| ネットワーク | 既存VPCの同一パブリックサブネット、内部通信はプライベートIP |
| 外部公開 | 自分のIPv4 /32からSSH、競技用へのHTTPS |

本番の競技用VMの台数・種類・ディスク容量を合わせています。公式READMEのベンチ環境はECS Fargate（8 vCPU / 8GBと記載）ですが、この構成ではSSHで扱えるEC2を使用します。メモリ・実行基盤・ネットワークやスコアは完全一致しません。3台への負荷分散やDB分離は初期状態で設定せず、競技と同様に自分でチューニングします。

- [構成と本番との差](docs/architecture.md)
- [構築・SSH・ベンチ実行手順](docs/setup.md)
- [Macからの計測・改善](docs/work-performance.md)
- [課金と削除](docs/cleanup.md)
- [CloudFormationテンプレート](cloudformation/isucon14-practice.yaml)

EC2 4台・EBS合計90GiB・パブリックIPv4 4個などの費用が発生します。既存のISUCON13スタックは更新せず、新しいスタックで作成してください。削除前に必要なコードやデータを退避してください。

テンプレートは独自の練習用です。公式AMIの共有は予告なく終了する可能性があります。AWS上でのAMI参照・起動・ベンチ実行は未検証です。
