[user]
	email = op://Private/git-identity/email
	name = op://Private/git-identity/username

[pull]
	rebase = false

[push]
	autoSetupRemote = true

[credential]
	helper = manager

[core]
	excludesFile = ~/.config/git/ignore
	editor = nvim

[init]
	defaultBranch = main

[alias]
	s = status
	st = status
	b = branch
	co = checkout
	cb = checkout -b
	c = commit
	cm = commit -m
	ca = commit --amend
	p = push
	pf = push --force-with-lease
	pl = pull
	d = diff
	ds = diff --staged
	l = log --oneline -10
	lg = log --graph --oneline --decorate
	ss = stash
	sp = stash pop
	sl = stash list
