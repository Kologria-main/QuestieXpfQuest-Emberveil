#!/bin/sh
set -eu

VERSION='2.0.0-beta1.20'
SCRIPT_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
SOURCE_ROOT="$SCRIPT_DIR/addon/pfQuest"
MANIFEST="$SCRIPT_DIR/installer/payload-manifest.sha256"

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

command -v sha256sum >/dev/null 2>&1 ||
  fail 'sha256sum is required to verify the offline payload.'
[ -d "$SOURCE_ROOT" ] || fail "Missing payload: $SOURCE_ROOT"
[ -f "$MANIFEST" ] || fail "Missing checksum manifest: $MANIFEST"

verify_payload() {
  verify_root=$1
  verify_count=0

  while IFS= read -r verify_line || [ -n "$verify_line" ]; do
    case "$verify_line" in ''|'#'*) continue ;; esac
    verify_hash=${verify_line%% *}
    verify_rel=${verify_line#*addon/pfQuest/}
    case "$verify_hash" in *[!0-9A-Fa-f]*|'') fail 'Invalid manifest hash.' ;; esac
    [ "${#verify_hash}" -eq 64 ] || fail 'Invalid manifest hash length.'
    case "$verify_rel" in ''|/*|../*|*/../*|*/..) fail "Unsafe manifest path: $verify_rel" ;; esac
    verify_file="$verify_root/$verify_rel"
    [ -f "$verify_file" ] || fail "Payload is missing: $verify_rel"
    verify_actual=$(sha256sum "$verify_file" | awk '{print $1}')
    [ "$verify_actual" = "$verify_hash" ] || fail "Checksum mismatch: $verify_rel"
    verify_count=$((verify_count + 1))
  done < "$MANIFEST"

  [ "$verify_count" -ge 250 ] || fail "Manifest is unexpectedly small: $verify_count files"
  verify_actual_count=$(find "$verify_root" -type f | wc -l | tr -d ' ')
  [ "$verify_actual_count" = "$verify_count" ] ||
    fail "Payload file count mismatch: expected $verify_count, found $verify_actual_count"

  if find "$verify_root" -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.com' \
      -o -iname '*.scr' -o -iname '*.bat' -o -iname '*.cmd' -o -iname '*.ps1' \) | grep -q .; then
    fail 'Executable content was found inside the addon payload.'
  fi
}

if [ "$#" -gt 1 ]; then
  fail 'Usage: ./INSTALL_KOQUEST_LINUX.sh /path/to/Emberveil/live/Azeroth/Interface/AddOns'
fi

ADDONS=${1:-}
if [ -z "$ADDONS" ]; then
  fail 'Pass the Emberveil Interface/AddOns directory as the only argument. See docs/installation.md for Wine and Proton examples.'
fi

ADDONS=$(CDPATH= cd -P "$ADDONS" 2>/dev/null && pwd) || fail "AddOns directory does not exist: $ADDONS"
[ "$(basename "$ADDONS")" = 'AddOns' ] || fail 'The target directory must be named AddOns.'
[ "$(basename "$(dirname "$ADDONS")")" = 'Interface' ] || fail 'AddOns must be directly inside an Interface directory.'

TARGET="$ADDONS/pfQuest"
TOKEN="$$-$(date +%s)"
STAGE="$ADDONS/.koquest-stage-$TOKEN"
ROLLBACK="$ADDONS/.koquest-rollback-$TOKEN"
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
BACKUP_ROOT="$STATE_HOME/koquest/backups/$(date +%Y%m%d-%H%M%S)-$TOKEN"
installed_new=0
moved_old=0
success=0

remove_private_dir() {
  private_path=$1
  case "$private_path" in
    "$ADDONS"/.koquest-stage-*|"$ADDONS"/.koquest-rollback-*) rm -rf -- "$private_path" ;;
    *) fail "Refusing unsafe cleanup path: $private_path" ;;
  esac
}

cleanup() {
  cleanup_status=$?
  trap - EXIT HUP INT TERM
  if [ "$success" -ne 1 ]; then
    if [ "$installed_new" -eq 1 ] && [ -d "$TARGET" ]; then
      mv "$TARGET" "$STAGE.failed" 2>/dev/null || true
    fi
    if [ "$moved_old" -eq 1 ] && [ -d "$ROLLBACK" ] && [ ! -e "$TARGET" ]; then
      mv "$ROLLBACK" "$TARGET" 2>/dev/null || true
      printf '%s\n' 'Previous pfQuest installation restored.' >&2
    fi
  fi
  [ ! -d "$STAGE" ] || remove_private_dir "$STAGE"
  [ ! -d "$ROLLBACK" ] || remove_private_dir "$ROLLBACK"
  [ ! -d "$STAGE.failed" ] || remove_private_dir "$STAGE.failed"
  exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

printf '%s\n' "KoQuest offline installer $VERSION"
verify_payload "$SOURCE_ROOT"
mkdir "$STAGE"
cp -a "$SOURCE_ROOT" "$STAGE/pfQuest"
verify_payload "$STAGE/pfQuest"

if [ -d "$TARGET" ]; then
  mkdir -p "$BACKUP_ROOT"
  cp -a "$TARGET" "$BACKUP_ROOT/pfQuest"
  mv "$TARGET" "$ROLLBACK"
  moved_old=1
  printf '%s\n' "Existing pfQuest backed up to: $BACKUP_ROOT/pfQuest"
elif [ -e "$TARGET" ]; then
  fail "Target exists but is not a directory: $TARGET"
fi

mv "$STAGE/pfQuest" "$TARGET"
installed_new=1
verify_payload "$TARGET"

[ ! -d "$ROLLBACK" ] || remove_private_dir "$ROLLBACK"
[ ! -d "$STAGE" ] || remove_private_dir "$STAGE"
success=1
printf '%s\n' "DONE: KoQuest $VERSION installed and verified at $TARGET"
printf '%s\n' 'Restart Emberveil completely, then enable pfQuest in the AddOns list.'
