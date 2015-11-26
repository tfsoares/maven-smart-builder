#!/bin/bash

# TODO:
# - in place substitution: this will allow setting needed variables without editing the file
#  -- sed -i -e "s/\#{i}/1\n  #{i}/" -e "s/\#{word}/dog/" test.txt
#

# USER SETTINGS
#BASE_DIR=/home/tsoares/bikeemotion
BASE_DIR=/home/tsoares/bikeemotion
#BASE_DIR=#{BASE_DIR}
#/home/tsoares/bikeemotion
COMMAND_OPTIONS=(
  "mvn clean install"
  "mvn clean install -o"
  "mvn clean install -DskipTests"
  "mvn clean install -DskipTests -o"
  "mvn clean deploy -DskipTests -Dnexus.ip=nexus.bikeemotion.com -Dnexus.port=9015 -Dnexus.repository=dev"
  "mvn clean deploy -DskipTests -Dnexus.ip=nexus.bikeemotion.com -Dnexus.port=9015 -Dnexus.repository=qa"
  "mvn clean install -P migrate -D datastore.port=5432"
  "mvn clean install -P migrate -D datastore.port=5432 -D flyway.goal=clean"
  "mvn clean install -P migrate -D datastore.ip=dev.bikeemotion.com"
  "mvn clean install -P migrate -D datastore.ip=qa.bikeemotion.com"
  "mvn clean install -P migrate -D datastore.port=5433"
  "mvn package -Pcluster -DskipTests"
  "mvn test"
  "mvn clean package"
  "mvn clean package -DskipTests"
  "git pull --rebase"
  "git pull origin develop"
  "git checkout develop"
  "git pull --rebase"
  "git stash"
  "git stash; git checkout develop && git pull --rebase"
  #{NEW_COMMAND}
)
# ------------

shopt -s expand_aliases  # Enables alias expansion.
alias reset='echo -e "\033c"'
export JAVA_HOME=/usr/lib/jvm/java-8-oracle/

DIALOG=$(which dialog)
[[ $DIALOG = "" ]] && DIALOG=$(which whiptail)

if [[ $DIALOG = "" ]]; then
  echo "[ERROR] install 'whiptail' or 'dialog'";
  exit;
fi

if [[ $BASE_DIR = "#{BASE_DIR}" ]]; then
  # ask for input and replace token
  exec 3>&1;
  cmd=$($DIALOG --title "Insert BASE_DIR:" --inputbox "Insert path:" 8 60 2>&1 1<&3 | sed -e 's/\//\\\//g' -e 's/\&/\\\&/g')
  exitcode=$?;
  exec 3>&-;

  # replace base_dir
  sed -i -e "0,/#{BASE_DIR}/s//${cmd}/" ${0}

  BASE_DIR=$(echo ${cmd} | sed -e 's/\\//g')
fi

if [ !  -d "$BASE_DIR" ]; then
  echo "[ERROR] Non-existing BASE_DIR: \""$BASE_DIR"\""
  exit;
fi

COMMAND_OPTIONS_STR=""
for (( l=1 ; l <= ${#COMMAND_OPTIONS[@]} ; l++ )) ; do
  COMMAND_OPTIONS_STR=$COMMAND_OPTIONS_STR" $l ${COMMAND_OPTIONS[l-1]//' '/_}"
done
COMMAND_OPTIONS_STR=$COMMAND_OPTIONS_STR" $l <Custom>"

function PRINT_LINE() {
  local a=0;
  local columns=$(tput cols);
  for (( a=0 ; a < $columns ; a++ )) ; do
     echo -n "="
     ((c+=1))
  done
}

function PREPARE_OPTIONS() {
  LIST=( $(find $BASE_DIR/$1 -name 'pom.xml' | sort) ) # get output as array

  OPTIONS=""
  OPTIONS_ARRAY=()
  OPTIONS_COUNTER=0;
  TEMP=""
  FILE=$2
  FILE_NAME_LENGTH=${#FILE}

  for (( l=0 ; l < ${#LIST[@]} ; l++ )) ; do
    PROJECT_PATH=$BASE_DIR"/"$1
    
    line=${LIST[l]:${#PROJECT_PATH}:${#LIST[l]}-${#PROJECT_PATH}-$((FILE_NAME_LENGTH+1))}

    IFS=/ read -a fields <<< "$line"

    f=${fields[0]}
    
    if [[ $f != "$TEMP" ]]; then
      TEMP=$f
      ((OPTIONS_COUNTER+=1))

      if [[ $f = pom* ]]; then
        f="/"
        OPTIONS=" $OPTIONS_COUNTER $f"$OPTIONS
      else
        OPTIONS=$OPTIONS" $OPTIONS_COUNTER $f"
      fi

      OPTIONS_ARRAY=("${OPTIONS_ARRAY[@]}" $f)
    fi
  done
}

function SHOW_MENU() {
  exec 3>&1;
  if [[ "$3" = "" ]]; then
    result=$($DIALOG --menu "On [$BASE_DIR$3]:" 0 0 $(($1+1)) all "In_all_sub_directories"$2 2>&1 1<&3)
  else
    result=$($DIALOG --menu "In [$3]:" 0 0 $1$2 2>&1 1<&3)  
  fi
  exitcode=$?;
  exec 3>&-;
}

function GET_COMMAND() {
  # $1 -> menu index
  local temp_exitcode=$exitcode;
  if [ $1 -gt ${#COMMAND_OPTIONS} ]; then
    exec 3>&1;
    cmd=$($DIALOG --title "Custom command" --inputbox "Insert custom command:" 8 120 2>&1 1<&3)
    exitcode=$?;
    exec 3>&-;
  else
    cmd=${COMMAND_OPTIONS[$1-1]}
  fi
  exitcode=$temp_exitcode;
}

LAST_PROJECT_I=0
LAST_PROJECT=("")

PREPARE_OPTIONS "" "pom.xml"
SHOW_MENU $OPTIONS_COUNTER "$OPTIONS" ""

while [ $exitcode -eq 0 -o $exitcode -eq 1 -o $exitcode -eq 255 ]; do
  if [ $exitcode -eq 0 ]; then # a


    if [[ $result = "all" ]]; then # b
      PROJECT_PATH=$BASE_DIR"/"
      DIRS=( $(find $BASE_DIR -maxdepth 2 -type d | grep ".git$" | sort) )

      SHOW_MENU ${#COMMAND_OPTIONS[@]} "$COMMAND_OPTIONS_STR" "In [$PROJECT]:"
      if [ $exitcode -eq 0 ]; then
        #cmd=${COMMAND_OPTIONS[result-1]}
        GET_COMMAND $result
        INPUT=""

        while [[ $INPUT != $'\e' ]]; do
          reset
          EXECUTION_RESULTS=""
          for (( l=0 ; l < ${#DIRS[@]} ; l++ )) ; do
            line=${DIRS[l]:${#PROJECT_PATH}:${#DIRS[l]}-${#BASE_DIR}-6} # 6 = '/.git' length

            PRINT_LINE
            echo "Running [$(tput rev)"$cmd"$(tput sgr0)] on [$(tput rev)"$PROJECT_PATH$line"$(tput sgr0)]"
            PRINT_LINE
            cd $PROJECT_PATH$line
            eval $cmd
            ret_code=$?
            echo
            echo

            if [ $ret_code -eq 0 ]; then
              EXECUTION_RESULTS+="   [$line] - SUCCESS\n"
            else
              EXECUTION_RESULTS+="   [$line] - FAILED\n"
            fi
          done
          PRINT_LINE
          echo -e "$(tput rev)EXECUTION RESULTS:$(tput sgr0)"
          PRINT_LINE
          echo -e "$EXECUTION_RESULTS"
          read -s -n 1 -p "== Press [ANY-KEY] to re-run command or [ESC] to go back to menu: " INPUT
        done
      fi

    else
      if [[ ${OPTIONS_ARRAY[result-1]} = "/" ]]; then # c
        SHOW_MENU ${#COMMAND_OPTIONS[@]} "$COMMAND_OPTIONS_STR" "In [$PROJECT]:"

        if [ $exitcode -eq 0 ]; then
	        GET_COMMAND $result
          INPUT=""
          while [[ $INPUT != $'\e' ]]; do
            reset
            cmdStatus="emblem-important.png"
            PRINT_LINE
            echo "Running [$(tput rev)"$cmd"$(tput sgr0)] on [$(tput rev)"$BASE_DIR$PROJECT"$(tput sgr0)]"
            PRINT_LINE
            cd $BASE_DIR$PROJECT
            eval $cmd && cmdStatus="emblem-default.png"

            notify-send -i "/usr/share/icons/gnome/48x48/emblems/$cmdStatus" "MavenSmartBuilder" "Finished running [$cmd] on [$PROJECT]"
            PRINT_LINE
            echo "Running [$(tput rev)"$cmd"$(tput sgr0)] on [$(tput rev)"$BASE_DIR$PROJECT"$(tput sgr0)]"
            PRINT_LINE
            read -s -n 1 -p "Press [ANY-KEY] to re-run command or [ESC] to go back to menu: " INPUT
          done
          ((LAST_PROJECT_I-=1))
        fi

    else # c
      PROJECT=$PROJECT"/"${OPTIONS_ARRAY[result-1]}
      PREPARE_OPTIONS $PROJECT"/"  "pom.xml"
      SHOW_MENU $OPTIONS_COUNTER "$OPTIONS" $PROJECT

      ((LAST_PROJECT_I+=1))
      LAST_PROJECT[LAST_PROJECT_I]=$PROJECT
    fi # c
    continue
    fi
  fi # a

  if [ $LAST_PROJECT_I -ne 0 ]; then # other than 'OK' exit code
    ((LAST_PROJECT_I-=1))
    PROJECT=${LAST_PROJECT[LAST_PROJECT_I]}
  fi
  if [[ $exitcode -eq 255 ]]; then # ESCAPE exitcode
    if [ $LAST_PROJECT_I -eq 0 ]; then
      reset
      exit;
    fi
    LAST_PROJECT_I=0
    PROJECT=${LAST_PROJECT[LAST_PROJECT_I]}
  fi

  PREPARE_OPTIONS $PROJECT"/"  "pom.xml"
  SHOW_MENU $OPTIONS_COUNTER "$OPTIONS" $PROJECT
done
