#!/bin/bash

# USER SETTINGS
BASE_DIR="/your/base/maven/projects/directory"
COMMAND_OPTIONS=(
  "mvn clean install"
  "mvn clean install -DskipTests"
  "mvn test"
  "mvn clean package"
  "mvn clean package -DskipTests"
  "git checkout")
# ------------

DIALOG=$(which dialog)
[[ $DIALOG = "" ]] && DIALOG=$(which whiptail)

if [[ $DIALOG = "" ]]; then
  echo "[ERROR] install 'whiptail' or 'dialog'";
  exit;
fi

if [ !  -d "$BASE_DIR" ]; then
  echo "[ERROR] Non-existing BASE_DIR: \""$BASE_DIR"\""
  exit;
fi

COMMAND_OPTIONS_STR=""
for (( l=1 ; l <= ${#COMMAND_OPTIONS[@]} ; l++ )) ; do
  COMMAND_OPTIONS_STR=$COMMAND_OPTIONS_STR" $l ${COMMAND_OPTIONS[l-1]//' '/_}"
done

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
    result=$($DIALOG --menu "On [$BASE_DIR$3]:" 30 60 $(($1+1)) all "In_all_sub_directories"$2 2>&1 1<&3)
  else
    result=$($DIALOG --menu "On [$BASE_DIR$3]:" 30 60 $1$2 2>&1 1<&3)  
  fi
  exitcode=$?;
  exec 3>&-;
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
        cmd=${COMMAND_OPTIONS[result-1]}
        INPUT=""

        while [[ $INPUT != $'\e' ]]; do
          reset
          EXECUTION_RESULTS=""
          for (( l=0 ; l < ${#DIRS[@]} ; l++ )) ; do
            line=${DIRS[l]:${#PROJECT_PATH}:${#DIRS[l]}-${#BASE_DIR}-6} # 6 = '/.git' length
            
            echo "==============================================================================="
            echo "Running [$(tput rev)"$cmd"$(tput sgr0)] on [$(tput rev)"$PROJECT_PATH$line"$(tput sgr0)]"
            echo "==============================================================================="          
            cd $PROJECT_PATH$line
            eval $cmd
            ret_code=$?
            echo
            echo

            
            if [ $ret_code -eq 0 ]; then
              EXECUTION_RESULTS+="   [$line] - SUCESS\n"
            else
              EXECUTION_RESULTS+="   [$line] - FAILED\n"
            fi
          done
          echo "==============================================================================="
          echo -e "$(tput rev)EXECUTION RESULTS:$(tput sgr0)"
          echo "==============================================================================="
          echo -e "$EXECUTION_RESULTS"
          read -s -n 1 -p "== Press [ANY-KEY] to re-run command or [ESC] to go back to menu: " INPUT
        done
      fi

    else
      if [[ ${OPTIONS_ARRAY[result-1]} = "/" ]]; then # c
        SHOW_MENU ${#COMMAND_OPTIONS[@]} "$COMMAND_OPTIONS_STR" "In [$PROJECT]:"
        
        if [ $exitcode -eq 0 ]; then
          cmd=${COMMAND_OPTIONS[result-1]}
          INPUT=""
          while [[ $INPUT != $'\e' ]]; do
            reset
            echo "==============================================================================="
            echo "Running [$(tput rev)"$cmd"$(tput sgr0)] on [$(tput rev)"$BASE_DIR$PROJECT"$(tput sgr0)]"
            echo "==============================================================================="          
            cd $BASE_DIR$PROJECT
            eval $cmd

            echo "==============================================================================="
            echo "Running [$(tput rev)"$cmd"$(tput sgr0)] on [$(tput rev)"$BASE_DIR$PROJECT"$(tput sgr0)]"
            echo "==============================================================================="
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
