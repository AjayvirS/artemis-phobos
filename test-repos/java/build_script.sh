#!/usr/bin/env bash
set -e

gradle () {
  echo '⚙️ executing gradle'
  # chmod +x ./gradlew
  ./gradlew clean test --info
}

main () {
  gradle
}

main "${@}"
