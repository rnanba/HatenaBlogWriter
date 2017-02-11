# HatenaBlogWriter (v0.1)

## 概要

はてなブログ用の[「はてなダイアリーライター」](http://www.hyuki.com/techinfo/hatena_diary_writer.html) 的なコマンドラインツール(になる予定)。

## 必要なもの

- ruby (たぶん 2.0 以降)
- atomutil (0.1.4)

## 使用法

### はてなブログの設定

はてなブログの [設定 - 基本設定 - 編集モード] で、「はてな記法モード」を設定してください(他のモードでの動作は未確認)。

### 設定

カレントディレクトリの ``config.yml`` に以下のように設定します。

```yaml:config.yml
id: your_hatena_id
blog_domain: your_blog.hatenablog.com
api_key: your_api_key
```

API Key は、はてなブログの [設定 - 詳細設定 - AtomPub - APIキー] に表
示されている文字列を記入します。

API Key が第三者の手に渡ると、第三者によるブログの改竄や削除が可能になっ
てしまいます。``config.yml`` をネット等に公開しないように注意してください。

### エントリファイルの作成(new サブコマンド)

エントリファイルを作成するには以下のコマンドを実行します。

```shell-session:
$ hbw.rb new
OK: エントリファイル '2017-02-12_01.txt' を作成しました。
$
```

``{今日の日付}_{連番}.txt`` 形式のファイル名でエントリファイルが作成されます。

## エントリファイルの編集

以下のような書式でエントリファイルを記述して、文字エンコーディングに UTF-8 を指定して保存します。

```none:2017-02-12_01.txt
title: サンプルエントリ
date: 2017-02-12
category: プログラミング, はてな
draft: no

ここから本文です。
はてな記法で記述します。
この記事は投稿時に公開されます。

```

ヘッダの意味は以下の通りです。

|ヘッダ|意味・書き方|
|:---|:---|
|title  |エントリのタイトルです。|
|date   |エントリの日付です。日付として表示される日時を「2017-02-12 01:56:00 +0900」のように記述します。時間やタイムゾーンは省略可能です。|
|category|エントリのカテゴリです。複数のカテゴリを設定する場合は「,」(カンマ)区切りで列挙します。|
|draft|記事を下書きにするか公開するかを指定します。「yes」を指定すると下書きに、「no」を指定すると公開になります。省略した場合は公開になります。|

### 投稿(post サブコマンド)

エントリファイル ``2017-02-12_01.txt`` を投稿するには以下のコマンドを実行します。

```shell-session:
$ hbw.rb post 2017-02-12_01.txt
OK: エントリを投稿しました。
OK: エントリファイルを投稿済にマークしました。
$
```

投稿に成功するとエントリファイルの末尾に投稿先を示すアドレスを含む行が追記されます。この行は記事の更新の際に必要なので削除しないように注意してください。

### 更新(update サブコマンド)

一度投稿したエントリファイル ``2017-02-12_01.txt`` を更新して、その内容で投稿先のエントリを更新するには以下のコマンドを実行します。

```shell-session:
$ hbw.rb update 2017-02-12_01.txt
OK: エントリを更新しました。
$
```

注意:
- 投稿先のエントリの内容はチェックしていません。最初の投稿後、はてなブログの編集画面で更新したエントリでも、警告無く上書きします。
- draft ヘッダを更新して下書きを公開することはできますが、公開したエントリを下書きに戻すことはできません。下書きに戻すにははてなブログの編集画面から設定してください。

## TODO

- hw.pl のように追加・変更したエントリファイルをまとめて投稿・更新する機能
- 投稿先のエントリの更新日時をチェックしてエントリファイルと同期する機能
