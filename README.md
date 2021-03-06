# Maven Smart Builder

This script allows the user to index all his projects and navigate them, executing an user defined range of CLI commands using the `ncurses` based `whiptail` command.

This will search a defined directory looking for `pom.xml` files, allowing to navigate them and, when in a directory that only has one `pom.xml`, presenting the pre-configured commands.

## How to use
-------------
* Download the script and place it where you want it
* Edit the script and change the `BASE_DIR` variable to the one you want to use
* Edit `COMPILE_OPTIONS`if you want other commands
* **Execute!**
* Keys:
	* Up and Down arrows to navigate the directories
	* Left and Right arrows to cycle between `Ok` and `Cancel`
	* `Ok`will select
	* `Cancel`will go to the previous directory
	* `Escape` to return to `BASE_DIR` or, if already on `BASE_DIR`, exits the script
* The 'In all sub directories' will allow the execution of a command in each of the first level `BASE_DIR` sub-directories, also capturing the command exit code and showing it to user in the end of the execution.
