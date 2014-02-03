dotfiles
========

repo for my dotfiles

## Assumptions
* **Git** installed obviously
* **Homebrew** installed and being used
* **iTerm2** installed

#### Homebrew installs
* **brew-cask** - install apps via brew - https://github.com/phinze/homebrew-cask
* **zsh**
* **vim**
* **rbenv** **ruby-build**

#### Submodules
* **prezto** - configuration framework for Zsh - https://github.com/sorin-ionescu/prezto

## Install
I'll create a script for this someday

1. Git clone this repo to your ~/ directory
2. Install **prezto** via their readme
3. Backup any dot files you wish to save
4. Symlink all the appropriate files for each folder
	* `ln -s 'git/gitconfig' '.gitconfig'`
	* .zlogin -> zprezto/zlogin
	* .zlogout -> zprezto/zlogout
	* .zpreztorc -> zprezto/zpreztorc
	* .zprofile -> zprezto/zprofile
	* .zshenv -> zprezto/zshenv
	* .zshrc -> zprezto/zshrc
	* .gitconfig -> git/gitconfig
	* .vimrc -> vim/vimrc

** remember ** to create a *.gitconfig.user* file that has your [user] info in it for github to know who you are
