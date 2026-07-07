# My dotfiles

Vim、Neovim、shell、WezTermなど、再現したいユーザー設定を管理するための
dotfilesです。LinuxとmacOSへのインストールに対応しています。

## 管理方針

リポジトリの`.gitignore`はホワイトリスト方式です。管理対象のパスだけを明示し、
アプリケーションが生成する状態、キャッシュ、Telemetry ID、認証情報は追跡しません。

主な管理対象は次のとおりです。

- Bash、Vim、tmux、EditorConfig
- Neovim、WezTerm
- GitHub CLIの`config.yml`（`hosts.yml`は管理しない）
- mdtsの表示設定
- Gitの共有可能な設定
- ユーザーコマンドとフォント

`~/.config`や`~/.bin`全体はsymlinkしません。管理対象のアプリディレクトリまたは
ファイルだけを個別にsymlinkします。

## インストール

リポジトリを任意の場所へcloneし、最初にdry-runで変更内容を確認します。

```sh
git clone git@github.com:hengin-eer/dotfiles.git ~/dotfiles
cd ~/dotfiles
./.bin/install.sh --dry-run
./.bin/install.sh
```

インストーラは以下を行います。

- 既存ファイルを`~/.dotbackup/<timestamp>/`へ退避
- 管理対象の設定だけをHOMEへsymlink
- Linuxでは`~/.local/share/fonts`、macOSでは`~/Library/Fonts`へフォントをsymlink
- vim-plugが存在しない場合は公式リポジトリからインストール

同じ内容のsymlinkは変更しないため、インストーラは再実行できます。

### 旧構成からの移行

`~/.config`または`~/.bin`がこのリポジトリへのsymlinkの場合、インストーラは
未管理の設定をHOME側の実ディレクトリへ移してから、管理対象だけをlinkし直します。
別の場所を指すsymlinkは安全のため変更せず、エラー終了します。

Gitの氏名・メールはローカルの`~/.gitconfig`に残ります。共有可能な設定だけを
`~/.gitconfig_shared`から読み込みます。GitHub CLIの認証情報を含む
`~/.config/gh/hosts.yml`もローカルに残ります。

## 管理対象の追加

新しい設定を追加するときは、次の両方へパスを明示します。

1. `.gitignore`のホワイトリスト
2. `.bin/install.sh`の`install_managed_paths`

秘密情報や再生成可能なファイルが同じディレクトリにある場合は、ディレクトリ全体では
なく必要なファイルだけを管理します。
