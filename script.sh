#!/bin/bash

# USER SETTINGS
BASE_DIR="/your/base/maven/projects/directory"
COMPILE_OPTIONS=(
  "mvn clean install"
  "mvn clean install -DskipTests"
  "mvn test"
  "mvn clean package"
  "mvn clean package -DskipTests")
# ------------

COMPILE_OPTIONS_STR=""
for (( l=1 ; l <= ${#COMPILE_OPTIONS[@]} ; l++ )) ; do
  COMPILE_OPTIONS_STR=$COMPILE_OPTIONS_STR" $l ${COMPILE_OPTIONS[l-1]//' '/_}"
done
echo $COMPILE_OPTIONS_STR

function PREPARE_OPTIONS() {
  LIST=( $(find $BASE_DIR/$1 -name 'pom.xml' | sort) ) # get output as array

  OPTIONS=""
  OPTIONS_ARRAY=()
  OPTIONS_COUNTER=0;
  TEMP=""

  for (( l=0 ; l < ${#LIST[@]} ; l++ )) ; do
    PROJECT_PATH=$BASE_DIR"/"$1
    
    line=${LIST[l]:${#PROJECT_PATH}:${#LIST[l]}-${#PROJECT_PATH}-8}

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
  result=$(whiptail --menu "On [$BASE_DIR$3]:" 30 60 $1$2 2>&1 1<&3)
  exitcode=$?;
  exec 3>&-;
}

LAST_PROJECT_I=0
LAST_PROJECT=("")

PREPARE_OPTIONS ""
SHOW_MENU $OPTIONS_COUNTER "$OPTIONS" ""

while [ $exitcode -eq 0 -o $exitcode -eq 1 -o $exitcode -eq 255 ]; do
  if [ $exitcode -eq 0 ]; then
    if [[ ${OPTIONS_ARRAY[result-1]} = "/" ]]; then
      SHOW_MENU ${#COMPILE_OPTIONS[@]} "$COMPILE_OPTIONS_STR" "In [$PROJECT]:"
      
      if [ $exitcode -eq 0 ]; then
        cmd=${COMPILE_OPTIONS[result-1]}
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
    else
      PROJECT=$PROJECT"/"${OPTIONS_ARRAY[result-1]}
      PREPARE_OPTIONS $PROJECT"/"
      SHOW_MENU $OPTIONS_COUNTER "$OPTIONS" $PROJECT

      #echo $LAST_PROJECT_I
      ((LAST_PROJECT_I+=1))
      LAST_PROJECT[LAST_PROJECT_I]=$PROJECT
      #echo "-eq 0 "${LAST_PROJECT}
    fi
    continue
  fi

  if [ $LAST_PROJECT_I -ne 0 ]; then
    ((LAST_PROJECT_I-=1))
    PROJECT=${LAST_PROJECT[LAST_PROJECT_I]}
    #exitcode=0
  fi
  if [[ $exitcode -eq 255 ]]; then
    LAST_PROJECT_I=0
    PROJECT=${LAST_PROJECT[LAST_PROJECT_I]}
  fi

  PREPARE_OPTIONS $PROJECT"/"
  SHOW_MENU $OPTIONS_COUNTER "$OPTIONS" $PROJECT
done

