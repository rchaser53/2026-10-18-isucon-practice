# CloudFormationによる構築・SSH・ベンチ実行

## 1. 前提とAMI確認

AWSのEC2/CloudFormation作成権限、東京リージョン、既存VPCとInternet Gatewayへのルートがあるパブリックサブネットが必要です。VPCとサブネットが同じVPCに属することを確認してください。

[公式README](https://github.com/isucon/isucon14)に掲載されている競技用AMIは `ami-0e334c50145a3ee41` です。東京リージョンのEC2「AMI」→「パブリックイメージ」で参照できるか確認してください。利用できない場合は[公式Packer](https://github.com/isucon/isucon14/tree/main/provisioning/packer)の `make build` で作ったISUCON14 AMIを `AmiId` に指定します。無関係なUbuntu AMIを競技用に指定してもアプリは入りません。

ベンチ用は別のUbuntu 24.04 amd64 AMIをSSM公開パラメータから取得します。後述のビルド作業が完了するまでベンチは使えません。スタック作成成功はベンチ準備完了を意味しません。

## 2. キーペアとパラメータ

EC2で `isucon-practice-key`（RSA、PEM）を作成し、PCに保存します。

```bash
mkdir -p ~/.ssh
mv ~/Downloads/isucon-practice-key.pem ~/.ssh/
chmod 400 ~/.ssh/isucon-practice-key.pem
```

[自分のIPv4](https://checkip.amazonaws.com/)に `/32` を付けた値を用意します。秘密鍵はGitやチャットに貼り付けません。

| パラメータ | 値 |
| --- | --- |
| AmiId | 公式AMIがデフォルト。利用可能性を事前確認 |
| BenchmarkAmiId | Ubuntu 24.04のSSM公開パラメータ（通常変更不要） |
| VpcId | 既存VPC |
| SubnetId | 同じVPCのパブリックサブネット |
| KeyName | isucon-practice-key |
| MyIpCidr | PCのグローバルIPv4 /32 |

## 3. 新しいスタックを作成

東京のCloudFormationコンソールで [isucon14-practice.yaml](../cloudformation/isucon14-practice.yaml) をアップロードし、スタック名 `isucon14-practice` で作成します。既存のISUCON13スタックには適用しないでください。リソース構成が変わるため、旧環境を保持したまま新規作成し、必要なコードを退避してから旧スタックを削除します。両方がある間は両方に課金されます。

`CREATE_COMPLETE` 後、出力に各台の `InstanceId`、`PublicIp`、`PrivateIp` があることを確認します。テンプレートは東京以外では拒否されます。失敗した場合はAMI共有、権限、サブネット、EC2在庫・クォータをイベントで確認してください。

## 4. 接続とサービス確認

[SSH設定例](../config/ssh_config.example)をPCの `~/.ssh/config` に追記し、4台のHostNameを出力のPublicIpに置き換えます。既存設定は上書きしません。初回は各台のホスト鍵の指紋を確認します。

```bash
ssh isucon-app1
ssh isucon-app2
ssh isucon-app3
ssh isucon-bench
```

それぞれ別セッションで接続します。競技用3台で以下を確認します。

```bash
cat /etc/os-release
lscpu
free -h
df -h
sudo systemctl status nginx mysql
sudo systemctl --type=service --state=running
sudo ss -lntp
sudo -iu isucon
ls -la /home/isucon/webapp
```

`isucon-practice` はApp1の別名です。ベンチVMは素のUbuntuなので、アプリのサービスはありません。

## 5. ベンチのビルド（ベンチVMのみ）

`ssh isucon-bench` で接続したUbuntu上で実行します。UbuntuのGoは公式ソースが要求するGo 1.23より古い場合がありますが、`GOTOOLCHAIN=auto` でgo.modが指定するツールチェーンを取得します。外部へのHTTPS接続が必要です。

```bash
sudo apt-get update
sudo apt-get install -y git golang-go ca-certificates util-linux
git clone https://github.com/isucon/isucon14.git ~/isucon14
cd ~/isucon14
git checkout 53f8b627e040c30ebec600457c6c97da008b84b0
cd bench
GOTOOLCHAIN=auto go build -o ~/isucon14-bench .
~/isucon14-bench run --help
git clone https://github.com/rchaser53/2026-10-18-isucon-practice.git ~/isucon-practice
```

PRのマージ前に試す場合、練習リポジトリはPRのブランチをチェックアウトしてください。ベンチ実装は確認済みの公式コミットに固定しています。

## 6. TLS証明書の確認・更新

公式証明書は期限切れの可能性があります。競技用各台で確認します。

```bash
sudo openssl x509 -in /etc/nginx/tls/_.xiv.isucon.net.crt -noout -dates
```

期限切れなら、練習用に各台で以下を実行します。元の証明書・鍵を先に退避し、練習環境専用の自己署名証明書に更新します。この差分も計測記録に残してください。

```bash
sudo cp -a /etc/nginx/tls /etc/nginx/tls.before-practice
sudo openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 30 \
  -keyout /etc/nginx/tls/_.xiv.isucon.net.key \
  -out /etc/nginx/tls/_.xiv.isucon.net.crt \
  -subj '/CN=xiv.isucon.net' \
  -addext 'subjectAltName=DNS:xiv.isucon.net,DNS:*.xiv.isucon.net' \
  -addext 'basicConstraints=critical,CA:TRUE'
sudo chmod 600 /etc/nginx/tls/_.xiv.isucon.net.key
sudo cp /etc/nginx/tls/_.xiv.isucon.net.crt /usr/local/share/ca-certificates/isucon-practice.crt
sudo update-ca-certificates
sudo nginx -t && sudo systemctl reload nginx
```

各台のマッチングサービスは `isuride.xiv.isucon.net` を参照するため、`/etc/hosts` の同名エントリがその台の `127.0.0.1` を指すことと、サービスのログを確認してください。

PCから公開証明書だけをベンチへ転送して信頼させます。以下は更新した各台についてPCで実行する例です（秘密鍵は転送しません）。

```bash
scp isucon-app1:/etc/nginx/tls/_.xiv.isucon.net.crt /tmp/isucon-app1.crt
scp /tmp/isucon-app1.crt isucon-bench:/tmp/isucon-app1.crt
ssh isucon-bench 'sudo cp /tmp/isucon-app1.crt /usr/local/share/ca-certificates/isucon-app1.crt && sudo update-ca-certificates'
```

App2、App3も同じ手順でホスト名・ファイル名を置き換えます。PCのブラウザで閲覧する場合も、同じ証明書を信頼させ、PCのhostsで `isuride.xiv.isucon.net` を対象台のPublicIpへ対応させます。

## 7. ベンチ実行

ベンチVMで実行します。`APP1_PRIVATE_IP` と `BENCHMARK_PRIVATE_IP` は出力の実際の値に置き換えてください。公開IPは使いません。`--addr` によりHTTPSのホスト名・SNIを保ったままApp1へ接続します。

```bash
cd ~/isucon14/bench
bash ~/isucon-practice/scripts/benchmark.sh -- ~/isucon14-bench run \
  --target https://isuride.xiv.isucon.net \
  --addr APP1_PRIVATE_IP:443 \
  --payment-url http://BENCHMARK_PRIVATE_IP:12345 \
  --fail-on-error -t 60
```

競技用からベンチの決済サーバー12345へ到達できる必要があります。決済サーバーはベンチ実行中に起動します。結果は `~/isucon-practice/results/` に保存されます。終了コードだけでなくスコア・検証エラーを確認してください。静的ファイルチェックは通常有効のまま実行します。

初期状態ではApp1だけが負荷先です。App2/App3を使うDB分離・負荷分散は自分で設定し、同じ負荷条件で比較します。[計測・改善手順](work-performance.md)と[削除手順](cleanup.md)も参照してください。

## 確認状況

設定は公式ソースと照合していますが、AWSでのAMI参照、スタック作成、上記ビルド・TLS更新・実ベンチは未実施です。
