# .bash_profile

# 初回起動時にtmuxを実行
# 現在は無効化(Weztermに移行中のため)
# if [ $SHLVL = 1 ]; then
  # tmux
# fi

# .bashrcの読み込み
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
