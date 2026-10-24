# WorkからEC2を操作し、計測・改善する

この手順は[構築・SSH接続](setup.md)の完了後に行います。PCのChatGPTデスクトップアプリからSSHホストを登録し、EC2のファイルとシェルに対して指示します。クラウド上の通常のチャットにIPを伝えるだけでは接続されません。

## 1. PCで接続設定

[設定例](../config/ssh_config.example)を確認し、PCの `~/.ssh/config` に追記します。ファイル全体を上書きせず、HostNameをCloudFormation出力のPublicIpに置き換えてください。

```bash
chmod 600 ~/.ssh/config
ssh isucon-practice
```

初回はホスト鍵の指紋を確認します。秘密鍵はPCに置いたまま使い、チャットやGitに貼り付けません。MyIpCidrはPCのグローバルIPv4 /32のままで利用でき、Work用の追加公開ポートは不要です。

## 2. EC2にCodex CLIを用意

SSH接続したubuntuユーザーで、[公式インストール手順](https://learn.chatgpt.com/docs/cli)に従ってCodex CLIをインストールし、`codex` を起動して認証します。以下は公式Linuxインストーラーの例です。実行前に内容を確認してください。

```bash
curl -fsSL https://chatgpt.com/codex/install.sh -o /tmp/install-codex.sh
less /tmp/install-codex.sh
sh /tmp/install-codex.sh
# インストーラーがPATHの追記を案内したら適用し、SSHに入り直す
codex --version
codex
```

認証方法はCLIの案内に従います。EC2から配布先・認証先・モデルへのHTTPS通信が必要です。PCから次を実行し、ログインシェルのPATHも確認します。

```bash
ssh isucon-practice 'command -v codex && codex --version'
```

アプリはSSHユーザーのログインシェルを使ってリモートのCodex app serverを起動します。app serverをインターネットに直接公開しないでください。

## 3. リモートプロジェクトを開く

デスクトップアプリの **Settings → Connections → SSH** で `isucon-practice` を追加・有効化し、EC2の作業フォルダを選びます。表示・利用可否はアプリのバージョンや組織設定によって異なります。

まずEC2にこのリポジトリをcloneしてください。

```bash
git clone https://github.com/rchaser53/2026-10-18-isucon-practice.git ~/isucon-practice
```

Workでは `/home/ubuntu/isucon-practice` を開き、アプリの実際の場所・所有者を調査します。ISUCONアプリは別ディレクトリにあるため、編集時は実際のアプリフォルダもプロジェクトとして開いてください。`sudo su - isucon` を別ターミナルで実行しても、Workの実行ユーザーは変わりません。まず `whoami` と `pwd` を確認し、サービス操作等は必要なコマンドに限ってsudoを使います。アプリ全体の所有者変更や権限緩和は行いません。

接続が使えない場合は、SSH先でCodex CLIを起動して同じ手順を進められます。

## 4. ベンチの準備と記録

このCloudFormationはアプリ用EC2を1台だけ作り、ベンチマーカーやそのネットワーク設定は作りません。[ISUCON13公式資料](https://github.com/isucon/isucon13)に従い、ベンチ環境・初期化方法・接続先を別途確認してください。実在しないベンチコマンドを固定していません。

ベンチホストにもこのリポジトリを配置し、実際のベンチディレクトリから以下を実行します。`/absolute/path/to/bench` と引数は実環境のコマンドに置き換えます。

```bash
bash ~/isucon-practice/scripts/benchmark.sh -- /absolute/path/to/bench <実際の引数>
```

Linux、Bash、util-linuxのflockが必要です。スクリプトはコマンドをそのまま実行し、終了コードを維持します。標準出力・標準エラーは画面に流さず、結果ディレクトリに保存します。

| ファイル | 内容 |
| --- | --- |
| metadata.txt | UTC開始時刻、ホスト、作業ディレクトリ、実行コマンド、現在のGit状態 |
| stdout.log / stderr.log | ベンチの標準出力・標準エラー |
| before.txt / after.txt | 実行ホストのuptime、メモリ、ディスクの前後比較 |
| result.txt | 終了コード、経過秒、UTC終了時刻 |

保存先はこのリポジトリの `results/`。同じ保存先を利用する実行をflockで排他し、重複時は75で終了します。`RESULTS_DIR` で保存先を変えられますが、別ホスト・別保存先・直接実行には排他が効きません。チームでベンチホストと保存先を統一してください。終了コード0だけでは競技上の成功を保証しないため、出力のスコアと検証エラーも確認します。

スクリプトのOS情報は**実行ホスト**の情報です。別ホストでベンチを動かす場合、アプリEC2のCPU・I/Oは別途計測してください。アプリ変更のコミットSHAも別に記録します。

## 5. 改善の進め方

1. サービス、アプリの場所、設定ファイル、初期化・デプロイ・ベンチコマンドを調べる。
2. 条件をそろえたベースラインを取得する。appホストで `vmstat 1`、必要ならsysstatの `pidstat` / `iostat` をベンチ時間内に限定して取得する。
3. NginxアクセスログとMySQLスロークエリを対象時間に限定して解析する。既存設定を保存してから計測設定を変更し、終了後に戻す。クエリはEXPLAINで実行計画を確認する。
4. 根拠のある仮説を1つ選び、変更、デプロイ、同条件で再計測する。悪化時はその変更だけ戻す。
5. 最終設定でサービス・EC2を再起動し、起動とベンチ成功を確認する。

t3.mediumはCPUクレジットによって性能が変わります。既存の[構成説明](architecture.md)も確認し、クレジット残量やインスタンスタイプを比較記録に含めてください。同じEC2上でベンチを動かすとリソースを奪い合うため、別ホストの結果と直接比較できません。

比較記録には、日時、アプリのコミット、差分、ベンチ実行先・コマンド、データ初期化条件、計測設定、スコア、エラー、採用・却下の判断を残します。ログにはユーザーデータや認証情報が含まれ得るため、resultsはGit対象外にしています。設定変更前のバックアップも公開リポジトリには置かないでください。

## 6. Workへの最初の指示例

> このEC2のISUCON性能改善を進めてください。最初にwhoamiとpwd、サービス、アプリと設定の場所、ベンチ環境を調査し、実行手順を記録してください。
> ベンチ環境が未準備なら、その不足を明示してください。準備できたらベースラインとCPU・I/O・アクセスログ・スロークエリを測定し、根拠のある仮説を1つずつ検証してください。
> アプリのコミットと変更差分、スコア、エラーを記録し、悪化した変更だけ戻してください。ベンチは同時実行せず、このリポジトリのscripts/benchmark.shを使ってください。
> 計測設定を元に戻した後、再起動と最終ベンチで動作を確認してください。

## 接続で困ったとき

- SSHが通らない：PublicIp、MyIpCidr、鍵、ubuntuユーザーを確認。EC2の停止・起動後はPublicIpが変わる場合があります。
- SSHは通るがWorkに接続できない：ログインシェルでcodexがPATHにあるか、CLI認証、アプリのConnections設定を確認。
- ファイルが書けない：実行ユーザーと所有者を確認し、適切なユーザー・プロジェクトで開く。
- 画面にSSH設定がない：アプリを更新し、利用可能な機能・組織設定を確認。CLIからの作業も可能です。

公式資料：[SSH接続](https://learn.chatgpt.com/docs/remote-connections#connect-to-an-ssh-host) / [Codex CLI](https://learn.chatgpt.com/docs/cli)

本手順・スクリプトの実EC2 / Work接続・公式ベンチによる検証は未実施です。
