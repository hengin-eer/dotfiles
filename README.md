# My dotfiles

Vim、Neovim、shell、WezTerm、Herdrなど、再現したいユーザー設定を管理するための
dotfilesです。LinuxとmacOSへのインストールに対応しています。

## 管理方針

リポジトリの`.gitignore`はホワイトリスト方式です。管理対象のパスだけを明示し、
アプリケーションが生成する状態、キャッシュ、Telemetry ID、認証情報は追跡しません。

主な管理対象は次のとおりです。

- Bash・zsh、Vim、EditorConfig
- Neovim、WezTerm（端末エミュレーター）
- Herdr（ターミナルマルチプレクサーとworktree管理）
- GitHub CLIの`config.yml`（`hosts.yml`は管理しない）
- mdtsの表示設定
- miseのツールバージョン設定
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
mise install
herdr integration install codex
npx skills add herdrdev/herdr --skill herdr -g
```

インストーラは以下を行います。

- 既存ファイルを`~/.dotbackup/<timestamp>/`へ退避
- 管理対象の設定だけをHOMEへsymlink
- Linuxでは`~/.local/share/fonts`、macOSでは`~/Library/Fonts`へフォントをsymlink
- vim-plugが存在しない場合は公式リポジトリからインストール
- `nvim` が PATH 上にない場合、OS・CPU に合う公式 stable 配布を curl で取得して
  `~/.local/opt/nvim-<platform>/` に展開し、`~/.local/bin/nvim` を symlink

同じ内容のsymlinkは変更しないため、インストーラは再実行できます。

Bash・zsh 共通の `~/.config/shell/path.sh` で `~/.local/bin`、`~/.bin` と
Homebrew の `/opt/homebrew/{bin,sbin}`・`/usr/local/{bin,sbin}` を PATH に追加します。
zsh は `.zprofile` と `.zshrc`、Bash は `.bash_profile` と `.bashrc` から読み込みます。
Starship はコマンドが見つかる場合だけシェルに合う初期化を行います。
既存のシェル設定は置き換え前にバックアップされるので、個人設定は必要に応じて戻してください。

インストール完了後は新しいターミナルを開くか、現在のシェルで次を実行してください。
インストーラの子プロセスから親シェルの PATH は変更できません。

```sh
. ~/.config/shell/path.sh
command -v nvim starship codex
nvim --version
```

Neovim は本体だけをコピーせず、`bin`・`lib`・`share` を一緒に配置します。
Apple Silicon / Intel Mac と Linux（WSLを含む）の arm64 / x86_64 に対応します。
既に PATH にある Neovim は変更しません。取得済みの公式アーカイブを使う場合は、
次のように指定できます（指定したアーカイブのバージョンを使用します）。

```sh
NVIM_ARCHIVE="$PWD/nvim-macos-arm64.tar.gz" ./.bin/install.sh
```

配布名・構成は [Neovim公式インストール手順](https://github.com/neovim/neovim/blob/master/INSTALL.md)
に沿っています。初回の通常起動では lazy.nvim とプラグインの取得にもネット接続が必要です。

### Mac で環境構築を完結させる修正計画

今回対応した範囲は、Bash・zsh 共通の PATH、Neovim の取得・配置、Starship の初期化、
WezTerm の Windows 専用設定の条件分岐です。
現時点の `.bin/install.sh` は Starship・Codex・mise 本体の自動導入までは行いません。

1. Starship が未導入の場合に、[公式インストーラ](https://starship.rs/guide/)を curl で
   取得し、`~/.local/bin` を指定して導入する。既存の Homebrew 版があれば再利用する。
2. Codex の公式導入方式と対応 CPU を確認し、未導入の場合だけ導入する。
   既存の curl 版（`~/.local/bin/codex`）と Homebrew 版は再利用する。
3. mise 本体の導入後に `mise install` を実行し、Herdr integration を含むセットアップを
   明示的なオプションで実行できるようにする。
4. Mac arm64 / Intel と WSL のクリーン環境で、初回導入・再実行・通信失敗時の動作と
   `nvim`・`starship`・`codex` の起動を確認する。


Herdrはmiseでバージョンを固定してインストールします。Herdrの設定ファイルだけを
`~/.config/herdr/config.toml`へsymlinkし、ログやセッション状態はHOME側に残します。
Codex integrationは`~/.codex/hooks.json`と`config.toml`を更新し、公式Herdr skillは
グローバルに追加します。

WezTermは端末エミュレーターとして引き続き使います。workspace、tab、pane、copy modeの
操作はHerdrが担当します。prefixは`Ctrl+G`で、pane分割は`d`（左右）/`r`（上下）、
移動は`h/j/k/l`、zoomは`z`、resize modeは`s`です。tab切替は`Tab`/`Shift+Tab`、
pane巡回は`Ctrl+Tab`/`Ctrl+Shift+Tab`、tab並べ替えは`Shift+[`/`Shift+]`です。

この環境のmiseでHerdrのGitHub artifact attestationがTSA証明書検証エラーになる場合は、
リリースのSHA-256を照合したうえで、GitHub attestation検証だけを一時的に無効化して
インストールできます（SLSA provenance検証は引き続き実行されます）。

```sh
MISE_GITHUB_ATTESTATIONS=false mise install github:herdrdev/herdr@0.9.1
```

### worktreeでの作業

Herdrでworktreeを作る前に、親workspaceで意図したベースブランチ（通常は`main`）へ
移動し、最新化して作業ツリーをcleanにします。Herdrは既定で作成元のworkspaceの
`HEAD`から新しいブランチを切ります。別の基準が必要ならworktree作成時にbaseを指定します。
つまり、どのブランチをベースにするかは親workspaceの状態または明示したbaseで決まり、
常に自動で`main`になるわけではありません。

各worktreeは独立した作業ディレクトリとindexを持つため、そこで通常のCLIやGitコマンドを
実行できます。一方、Gitのブランチ情報やオブジェクトは共有されます。同じブランチを複数の
worktreeで同時にcheckoutすることはできず、branch/refを書き換える操作も他worktreeへ
影響し得ます。複数の作業で同一ブランチを使い回さないでください。

エージェントはworktree内で実装、確認、commit、push、PR作成まで進めます。merge、rebase、
ブランチ削除、worktree削除、reset、clean、force-pushは人の確認後に行います。Codex向けの
コマンド承認ルールは`.codex/rules/herdr-git.rules`で管理し、既存の`default.rules`は変更
しません。自然言語の共通指示は`.codex/AGENTS.md`から`~/.codex/AGENTS.md`へsymlink
します。

## Codex personal skills

Codexスキル本体は別リポジトリの
[`codex-personal-skills`](https://github.com/hengin-eer/codex-personal-skills)で管理します。
dotfilesには複製せず、スキルリポジトリのinstallerが`~/.agents/skills`へsymlinkします。

```sh
git clone git@github.com:hengin-eer/codex-personal-skills.git ~/projects/codex-personal-skills
cd ~/projects/codex-personal-skills
python3 scripts/install_skills.py --dry-run --migrate-legacy
python3 scripts/install_skills.py --migrate-legacy
```

Windowsデスクトップ版をWSLエージェントで使う場合も、WSL側で実行します。反映されない
場合はデスクトップ版を再起動して新しいチャットを開始してください。

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
