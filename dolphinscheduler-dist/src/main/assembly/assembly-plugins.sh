#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -xeo pipefail

PLUGINS_ASSEMBLY_SKIP=$1

DIST_DIR="$(readlink -f $(pwd)/target)"
BIN_DIR=$(ls -d $DIST_DIR/apache-dolphinscheduler-*-bin | head -n1)
if [ ! -d "$BIN_DIR" ]; then
  echo "$BIN_DIR not found!!!"
  exit 1
fi

# move *-plugins/target/*-plugin/target/*.jar to *-plugins/
PLUGINS_PATH=(
alert-plugins
datasource-plugins
storage-plugins
task-plugins
)

if [ $PLUGINS_ASSEMBLY_SKIP == "true" ]; then
  rm -rf $BIN_DIR/plugins/*
else
  for plugin_path in "${PLUGINS_PATH[@]}"; do
    PLUGIN_DIR="$BIN_DIR/plugins/$plugin_path"
    [ ! -d "$PLUGIN_DIR" ] && continue
    mv -f "$PLUGIN_DIR"/*/*/*.jar "$PLUGIN_DIR/"
    rm -rf "$PLUGIN_DIR"/*/
  done
fi

# move *-server/libs/*.jar to libs/ and create symbolic link in *-server/libs/
MODULES_PATH=(
api-server
master-server
worker-server
alert-server
tools
)

SHARED_LIB_DIR="$BIN_DIR/libs"
mkdir -p "$SHARED_LIB_DIR"

for module in "${MODULES_PATH[@]}"; do
    MODULE_LIB_DIR="$BIN_DIR/$module/libs"
    [[ ! -d "$MODULE_LIB_DIR" ]] && continue
    cd "$MODULE_LIB_DIR" || continue
    local_jars=()
    for jar in *.jar; do
        [[ -f "$jar" ]] && local_jars+=("$jar")
    done
    [[ ${#local_jars[@]} -eq 0 ]] && { cd - >/dev/null 2>&1; continue; }
    cp -f "${local_jars[@]}" "$SHARED_LIB_DIR/"
    rm -f "${local_jars[@]}"
    for jar_name in "${local_jars[@]}"; do
        ln -sf ../../libs/"$jar_name" "$jar_name"
    done
    cd - >/dev/null 2>&1
done

# create symbolic link for standalone-server
ln -sf "$BIN_DIR/tools/sql/sql" "$BIN_DIR/standalone-server/sql"

# repack bin tar
BIN_DIR_NAME=$(basename $BIN_DIR)
BIN_TAR_FILE_NAME=$BIN_DIR_NAME.tar.gz
tar -zcf "$DIST_DIR/$BIN_TAR_FILE_NAME" -C "$DIST_DIR" "$BIN_DIR_NAME"

echo "assembly-plugins.sh done"
