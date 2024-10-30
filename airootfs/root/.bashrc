#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1="\[\033[1;32m\]\342\224\214\342\224\200\$([[ \$(/etc/htb/vpnbash.sh) == *\"10.\"* ]] && echo \"[\[\033[1;34m\]\$(nmcli c show | head -n2 | tail -n1 | cut -d' ' -f1)\[\033[1;32m\]]\342\224\200[\[\033[1;37m\]\$(/etc/htb/vpnbash.sh)\[\033[1;32m\]]\342\224\200\")[\[\033[1;37m\]\u\[\033[01;32m\]@\[\033[01;34m\]\h\[\033[1;32m\]]\342\224\200[\[\033[1;37m\]\w\[\033[1;32m\]]\n\[\033[1;32m\]\342\224\224\342\224\200\342\224\200\342\225\274 [\[\e[01;33m\]★\[\e[01;32m\]]\\$ \[\e[0m\]"
