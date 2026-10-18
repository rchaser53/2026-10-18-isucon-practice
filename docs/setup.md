# CloudFormationによる構築とSSH接続

## 0. 前提条件

- AWSアカウントとEC2/CloudFormationを作成できる権限
- AWSリージョンは**東京（ap-northeast-1）**
- 既存VPCと、インターネットゲートウェイ経由で外部接続可能なパブリックサブネット
- SSHクライアントとインターネット接続環境

事前に[料金と片付け](cleanup.md)を読み、予算アラートも設定してください。

## AMIが見つからない場合（最初に確認）

公式READMEに記載された `ami-041289d910c114864` は、公開終了などにより現在利用できない場合があります。まず東京リージョンのEC2コンソール「AMI」→「パブリックイメージ」で検索してください。見つからなければ同じIDを繰り返し指定してもデプロイできません。

公式の代替手段は [ISUCON13 provisioning/packer](https://github.com/isucon/isucon13/tree/main/provisioning/packer) にある `make build` でAMIを自作することです。PackerとAnsibleのビルドには追加の計算リソース・時間・費用が必要です。完了後、そのアカウント・東京リージョンに作成されたAMI IDをスタックの `AmiId` に指定します。**別の無関係なUbuntu AMIを指定してもISUCONアプリは入りません。**

AWS上でAMIを確認・自作できるまではスタックの作成を進めないでください。

## 1. SSHキーペアの作成

[EC2コンソール](https://console.aws.amazon.com/ec2/)で東京リージョンを選択。「キーペア」→「作成」から、名前 `isucon-practice-key`、タイプ RSA、形式 PEM で作ります。

Mac / Linux / WSLの例：

```bash
mkdir -p ~/.ssh
mv ~/Downloads/isucon-practice-key.pem ~/.ssh/
chmod 400 ~/.ssh/isucon-practice-key.pem
```

秘密鍵は再ダウンロードできません。リポジトリにコミットしないでください。

## 2. パラメータの確認

[VPCコンソール](https://console.aws.amazon.com/vpc/)で、既存の `VpcId` と、同じVPCにあるパブリック `SubnetId` を確認してください。サブネットのルートテーブルに `0.0.0.0/0 → igw-...` のルートが必要です。

[checkip.amazonaws.com](https://checkip.amazonaws.com/)で自分のIPv4を調べ、末尾に `/32` をつけます。例えば `203.0.113.10/32` ですが、これはダミー値であり**実際のIPに置き換えて**ください。

## 3. CloudFormationスタックの作成

1. [CloudFormationコンソール](https://console.aws.amazon.com/cloudformation/)を東京リージョンで開き、「スタックの作成」を選択。
2. 「テンプレートファイルのアップロード」を選び、[isucon13-one-ec2.yaml](../cloudformation/isucon13-one-ec2.yaml)を指定。
3. スタック名に `isucon13-practice` を入力。
4. パラメータを設定。

| パラメータ | 値 |
| --- | --- |
| AmiId | 東京リージョンで参照できるISUCON13用AMI ID（必須） |
| VpcId | 既存VPCのID |
| SubnetId | 対象VPCのパブリックサブネット |
| KeyName | isucon-practice-key |
| MyIpCidr | 自分のグローバルIPv4 + /32 |
| InstanceType | t3.medium（デフォルト） |
| VolumeSize | 30（GiB） |

5. オプションを確認して作成、`CREATE_COMPLETE` になるまでイベントを確認。
6. 「出力」タブの `PublicIp` と `SSHCommand` を確認する。

失敗した場合はイベント欄を確認します。AMIの共有停止、IP/サブネットの不一致、権限不足、インスタンスの在庫不足などが原因になり得ます。

## 4. SSH接続

```bash
ssh -i ~/.ssh/isucon-practice-key.pem ubuntu@<PublicIp>
```

上記の `<PublicIp>` は実際の値に置き換えます。初回はホスト鍵の指紋を確認してください。

```bash
sudo su - isucon
whoami
pwd
ls -la
```

## 5. 環境確認

```bash
cat /etc/os-release
lscpu
free -h
df -h
sudo systemctl status nginx
sudo systemctl status mysql
sudo ss -lntp
```

インストール済みアプリやサービス名は公式AMIの設定を確認してください。サービスが起動しているかは `systemctl --type=service --state=running` でも確認できます。

## 6. 練習

1. どのサービスがどのポートで待ち受けているか確認。
2. Nginx設定とアプリ、SQLのコードを調査。
3. ログ・CPU・メモリを計測して改善。
4. EC2再起動後もアプリが正常に立ち上がるか確認。

ベンチマーカーはこの1台の構成には含まれません。本番同等の負荷試験には別途環境が必要です。
