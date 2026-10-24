# CloudFormationによる構築・SSH・ベンチ実行

## 1. AMIの利用可否を最初に確認

[公式ISUCON13 README](https://github.com/isucon/isucon13)のAMIは東京の `ami-041289d910c114864` です。**このIDの現在の公開状態は未検証です。ISUCON14と同様に共有終了している可能性があります。**

東京リージョンのEC2コンソール「AMI」→「パブリックイメージ」でIDを検索してください。AWS CLIを使える場合、スタックを作成するのと同じアカウントで確認できます。

```bash
aws ec2 describe-images --region ap-northeast-1 \
  --image-ids ami-041289d910c114864 \
  --query 'Images[].{Id:ImageId,State:State,Public:Public,Owner:OwnerId}'
```

`available` で参照できることを確認します。見つからない、権限エラーになる場合は、そのIDでスタックを作成しても解決しません。[公式Packer](https://github.com/isucon/isucon13/tree/main/provisioning/packer)で `make build` を実行し、作成されたISUCON13 AMIを `AmiId` に指定します。Packer/Ansibleとビルド用AWSリソースが必要で、追加の費用・時間がかかります。公式READMEの手順に従ってください。汎用Ubuntu AMIではアプリ・DNS・ベンチが入りません。

## 2. キーペアとパラメータ

AWSのEC2/CloudFormation作成権限、東京リージョン、既存VPCとInternet Gatewayへのルートがあるパブリックサブネットが必要です。VPCとサブネットの所属が一致することを確認します。

EC2で `isucon-practice-key`（RSA、PEM）を作成し、PCに保存します。

```bash
mkdir -p ~/.ssh
mv ~/Downloads/isucon-practice-key.pem ~/.ssh/
chmod 400 ~/.ssh/isucon-practice-key.pem
```

[自分のIPv4](https://checkip.amazonaws.com/)に `/32` を付けた値を用意します。秘密鍵はGitやチャットに貼り付けません。

| パラメータ | 値 |
| --- | --- |
| AmiId | 利用可否を確認した公式ISUCON13 AMI、または公式Packerで自作したAMI |
| VpcId | 既存VPC |
| SubnetId | 同じVPCのパブリックサブネット |
| KeyName | isucon-practice-key |
| MyIpCidr | PCのグローバルIPv4 /32 |

## 3. 新しいスタックを作成

東京のCloudFormationコンソールで [isucon13-practice.yaml](../cloudformation/isucon13-practice.yaml) をアップロードし、スタック名 `isucon13-practice` で作成します。既存スタックに同名があれば `isucon13-practice-v2` 等の別名を使います。旧1台構成やISUCON14スタックは直接更新せず、必要なコードを退避してから削除してください。両方がある間は両方に課金されます。

`CREATE_COMPLETE` 後、出力に各台の `InstanceId`、`PublicIp`、`PrivateIp` があることを確認します。東京以外は拒否されます。失敗した場合はAMI共有、権限、サブネット、EC2在庫・クォータをイベントで確認してください。

## 4. 接続と競技用サービス確認

[SSH設定例](../config/ssh_config.example)をPCの `~/.ssh/config` に追記し、4台のHostNameを対応するPublicIpに置き換えます。既存設定は上書きせず、各台のホスト鍵の指紋を確認してください。

```bash
ssh isucon-app1
ssh isucon-app2
ssh isucon-app3
ssh isucon-bench
```

それぞれ別セッションで接続します。`isucon-practice` はApp1の別名です。競技用3台で以下を確認します。

```bash
cat /etc/os-release
lscpu
free -h
df -h
sudo systemctl status nginx mysql pdns
sudo systemctl --type=service --state=running
sudo ss -lntup
sudo -iu isucon
ls -la /home/isucon/webapp
```

### DNSが返すIPをプライベートIPに合わせる

競技用各台の `/home/isucon/env.sh` の `ISUCON13_POWERDNS_SUBDOMAIN_ADDRESS` を、**その台自身のPrivateIp**へ変更します。公式AMIの初回サービスは公開IPを設定する場合があります。例えばApp1で、出力の実際の値に置き換えて実行します。

```bash
sudo cp -a /home/isucon/env.sh /home/isucon/env.sh.before-practice
sudo sed -i 's/^ISUCON13_POWERDNS_SUBDOMAIN_ADDRESS=.*/ISUCON13_POWERDNS_SUBDOMAIN_ADDRESS="APP1_PRIVATE_IP"/' /home/isucon/env.sh
sudo systemctl restart isupipe-go
```

Go以外を使う場合は実行中の `isupipe-*` サービス名に置き換えます。ベンチの初期化によりこの設定がDNSレコードに反映されます。App2/App3も各台のPrivateIpで同様に設定してください。ベンチの `--webapp` に登録したIP以外をDNSが返すと検証に失敗します。

## 5. ベンチ専用VMの準備

公式ISUCON13 AMIにはベンチが同梱されています。`ssh isucon-bench` で接続し、不要なアプリサービスを確認して停止します。以下は初期のGo実装の場合です。別の `isupipe-*` が動いていればそれも停止します。

```bash
sudo systemctl disable --now nginx mysql pdns isupipe-go
sudo -iu isucon
ls -l /home/isucon/bench_linux_amd64
/home/isucon/bench_linux_amd64 run --help
git clone https://github.com/rchaser53/2026-10-18-isucon-practice.git ~/isucon-practice
```

PRのマージ前は、このリポジトリをPRのブランチ `feat/isucon14-official-ami` に切り替えてください（既存PRのブランチ名を保持しています）。ベンチの再ビルドが必要な場合は[公式README](https://github.com/isucon/isucon13#ベンチマーカーのビルド)に従います。同梱バイナリがないAMIではその準備が必要です。

## 6. TLS証明書の確認・更新

公式証明書は期限切れの可能性があります。競技用各台で確認します。

```bash
sudo openssl x509 -in /etc/nginx/tls/_.u.isucon.dev.crt -noout -dates
```

期限切れなら、練習用に各台で以下を実行します。元の証明書・鍵を先に退避し、練習環境専用の自己署名証明書に更新します。この差分も計測記録に残してください。

```bash
sudo cp -a /etc/nginx/tls /etc/nginx/tls.before-practice
sudo openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 30 \
  -keyout /etc/nginx/tls/_.u.isucon.dev.key \
  -out /etc/nginx/tls/_.u.isucon.dev.crt \
  -subj '/CN=u.isucon.dev' \
  -addext 'subjectAltName=DNS:u.isucon.dev,DNS:*.u.isucon.dev' \
  -addext 'basicConstraints=critical,CA:TRUE'
sudo chmod 600 /etc/nginx/tls/_.u.isucon.dev.key
sudo cp /etc/nginx/tls/_.u.isucon.dev.crt /usr/local/share/ca-certificates/isucon-practice.crt
sudo update-ca-certificates
sudo nginx -t && sudo systemctl reload nginx
```

PCから公開証明書だけをベンチへ転送して信頼させます。以下は更新した各台についてPCで実行する例です（秘密鍵は転送しません）。

```bash
scp isucon-app1:/etc/nginx/tls/_.u.isucon.dev.crt /tmp/isucon-app1.crt
scp /tmp/isucon-app1.crt isucon-bench:/tmp/isucon-app1.crt
ssh isucon-bench 'sudo cp /tmp/isucon-app1.crt /usr/local/share/ca-certificates/isucon-app1.crt && sudo update-ca-certificates'
```

App2、App3も同じ手順でホスト名・ファイル名を置き換えます。PCのブラウザで閲覧する場合も、同じ証明書を信頼させ、PCのhostsで `pipe.u.isucon.dev` を対象台のPublicIpへ対応させます。

## 7. ベンチ実行

ベンチVMの `isucon` ユーザーで実行します。`APP1_PRIVATE_IP` などはCloudFormation出力の実際の値に置き換えます。ISUCON13のベンチはApp1のPowerDNSで名前解決し、HTTPSでアプリに接続します。公開IPを指定しないでください。

```bash
cd /home/isucon
bash ~/isucon-practice/scripts/benchmark.sh -- /home/isucon/bench_linux_amd64 run \
  --target https://pipe.u.isucon.dev \
  --nameserver APP1_PRIVATE_IP --enable-ssl \
  --webapp APP2_PRIVATE_IP --webapp APP3_PRIVATE_IP \
  --pretest-only
```

初期化・整合性チェックが成功したら、同じコマンドから `--pretest-only` を外して負荷走行します。DNS（UDP/TCP 53）とHTTPS（443）がベンチから競技用に通る必要があります。ISUCON14の `--addr` / `--payment-url` / `--fail-on-error` / `-t` は使いません。

初期状態ではApp1が負荷先です。`--webapp` はDNS応答として許可するアドレスを追加する指定で、負荷分散を自動設定しません。DB分離・DNSレコード・負荷分散は自分で設定し、同条件で比較します。

ラッパーの記録は `~/isucon-practice/results/` に保存されます。公式ベンチの既定ログは `/tmp/staff.log`、`/tmp/contestant.log`、結果JSONは `/tmp/result.json` です。後者は次の実行で上書きされるので別途退避してください。終了コードだけでなく結果の `pass`・`score`・検証エラーを確認します。

公式動画・サムネイル配信は廃止されているためブラウザ表示は当日と一致しません。[計測・改善](work-performance.md)と[削除](cleanup.md)も参照してください。

## 確認状況

設定・CLI・サービス構成は公式コミット `8f6afdc3603f0c661368de4659a7240862f59623` と照合しています。AWSでのAMI参照、スタック作成、TLS更新、実ベンチは未実施です。
