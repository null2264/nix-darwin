#! @shell@
set -e
set -o pipefail
export PATH=@path@:$PATH

showSyntax() {
  echo "linux-version [--help|--linux-revision|--nixpkgs-revision|--configuration-revision|--json]" >&2
}

case "$1" in
  --help)
    showSyntax
    ;;
  --linux-revision)
    revision="$(jq --raw-output '.linuxRevision // "null"' < /run/current-system/linux-version.json)"
    if [[ "$revision" == "null" ]]; then
      echo "$0: nix-not-nixos commit hash is unknown" >&2
      exit 1
    fi
    echo "$revision"
    ;;
  --nixpkgs-revision)
    revision="$(jq --raw-output '.nixpkgsRevision // "null"' < /run/current-system/linux-version.json)"
    if [[ "$revision" == "null" ]]; then
      echo "$0: Nixpkgs commit hash is unknown" >&2
      exit 1
    fi
    echo "$revision"
    ;;
  --configuration-revision)
    revision="$(jq --raw-output '.configurationRevision // "null"' < /run/current-system/linux-version.json)"
    if [[ "$revision" == "null" ]]; then
      echo "$0: configuration commit hash is unknown" >&2
      exit 1
    fi
    echo "$revision"
    ;;
  --json)
    cat /run/current-system/linux-version.json
    ;;
  *)
    label="$(jq --raw-output '.linuxLabel // "null"' < /run/current-system/linux-version.json)"
    if [[ "$label" == "null" ]]; then
      showSyntax
      exit 1
    fi
    echo "$label"
    ;;
esac

