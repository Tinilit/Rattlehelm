#!/usr/bin/env bash
set -euo pipefail

version=4.7.2
base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
editor="Godot_v${version}-stable_linux.x86_64"
templates="Godot_v${version}-stable_export_templates.tpz"
tool_dir="${1:?Usage: install_godot.sh /absolute/tool/directory}"
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"

mkdir -p "$tool_dir" "$template_dir"
cd "$tool_dir"
curl --fail --silent --show-error --location --retry 3 "$base/$editor.zip" --output "$editor.zip"
curl --fail --silent --show-error --location --retry 3 "$base/$templates" --output "$templates"

printf '%s  %s\n' \
  '9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65' "$editor.zip" \
  'ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079' "$templates" \
  | sha512sum --check --strict

unzip -qo "$editor.zip" "$editor"
install -m 0755 "$editor" godot
unzip -jo "$templates" 'templates/version.txt' 'templates/web_nothreads_release.zip' -d "$template_dir"
test "$(cat "$template_dir/version.txt")" = "${version}.stable"
[[ "$(./godot --version)" == "${version}.stable.official."* ]]
