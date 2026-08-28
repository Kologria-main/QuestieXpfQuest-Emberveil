#!/bin/sh
set -eu

VERSION='2.0.0-beta1.21'
SCRIPT_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
SOURCE_ROOT="$SCRIPT_DIR/addon/KoQuest"
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
    verify_rel=${verify_line#*addon/KoQuest/}
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

is_legacy_koquest() {
  legacy_root=$1
  [ -d "$legacy_root" ] || return 1
  for legacy_toc in "$legacy_root/pfQuest.toc" "$legacy_root/KoQuest.toc"; do
    if [ -f "$legacy_toc" ] && grep -qi '^## Title:.*KoQuest' "$legacy_toc" \
        && grep -qi '^## Version:[[:space:]]*EV-' "$legacy_toc"; then
      return 0
    fi
  done
  return 1
}

if [ "$#" -gt 2 ]; then
  fail 'Usage: ./INSTALL_KOQUEST_LINUX.sh /path/to/Interface/AddOns [/path/to/SavedVariables]'
fi

ADDONS=${1:-}
SAVED_ROOT=${2:-}
if [ -z "$ADDONS" ]; then
  fail 'Pass the Emberveil Interface/AddOns directory. See docs/installation.md for Wine and Proton examples.'
fi

ADDONS=$(CDPATH= cd -P "$ADDONS" 2>/dev/null && pwd) || fail "AddOns directory does not exist: $ADDONS"
[ "$(basename "$ADDONS")" = 'AddOns' ] || fail 'The target directory must be named AddOns.'
[ "$(basename "$(dirname "$ADDONS")")" = 'Interface' ] || fail 'AddOns must be directly inside an Interface directory.'

TARGET="$ADDONS/KoQuest"
LEGACY="$ADDONS/pfQuest"
TOKEN="$$-$(date +%s)"
STAGE="$ADDONS/.koquest-stage-$TOKEN"
ROLLBACK="$ADDONS/.koquest-rollback-$TOKEN"
LEGACY_ROLLBACK="$ADDONS/.koquest-legacy-$TOKEN"
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
BACKUP_ROOT="$STATE_HOME/koquest/backups/$(date +%Y%m%d-%H%M%S)-$TOKEN"
installed_new=0
moved_old=0
moved_legacy=0
success=0

remove_private_dir() {
  private_path=$1
  case "$private_path" in
    "$ADDONS"/.koquest-stage-*|"$ADDONS"/.koquest-rollback-*|"$ADDONS"/.koquest-legacy-*)
      rm -rf -- "$private_path" ;;
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
      printf '%s\n' 'Previous KoQuest installation restored.' >&2
    fi
    if [ "$moved_legacy" -eq 1 ] && [ -d "$LEGACY_ROLLBACK" ] && [ ! -e "$LEGACY" ]; then
      mv "$LEGACY_ROLLBACK" "$LEGACY" 2>/dev/null || true
      printf '%s\n' 'Legacy KoQuest pfQuest folder restored.' >&2
    fi
  fi
  [ ! -d "$STAGE" ] || remove_private_dir "$STAGE"
  [ ! -d "$ROLLBACK" ] || remove_private_dir "$ROLLBACK"
  [ ! -d "$LEGACY_ROLLBACK" ] || remove_private_dir "$LEGACY_ROLLBACK"
  [ ! -d "$STAGE.failed" ] || remove_private_dir "$STAGE.failed"
  exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

printf '%s\n' "KoQuest offline installer $VERSION"
verify_payload "$SOURCE_ROOT"
mkdir "$STAGE"
cp -a "$SOURCE_ROOT" "$STAGE/KoQuest"
verify_payload "$STAGE/KoQuest"

legacy_koquest=0
if is_legacy_koquest "$LEGACY"; then legacy_koquest=1; fi

if [ -d "$TARGET" ] || [ "$legacy_koquest" -eq 1 ]; then
  mkdir -p "$BACKUP_ROOT"
fi

if [ -d "$TARGET" ]; then
  cp -a "$TARGET" "$BACKUP_ROOT/KoQuest"
  mv "$TARGET" "$ROLLBACK"
  moved_old=1
  printf '%s\n' "Existing KoQuest backed up to: $BACKUP_ROOT/KoQuest"
elif [ -e "$TARGET" ]; then
  fail "Target exists but is not a directory: $TARGET"
fi

if [ "$legacy_koquest" -eq 1 ]; then
  cp -a "$LEGACY" "$BACKUP_ROOT/pfQuest-legacy-KoQuest"
  mv "$LEGACY" "$LEGACY_ROLLBACK"
  moved_legacy=1
  printf '%s\n' "Legacy KoQuest pfQuest folder backed up to: $BACKUP_ROOT/pfQuest-legacy-KoQuest"

  if [ -n "$SAVED_ROOT" ]; then
    SAVED_ROOT=$(CDPATH= cd -P "$SAVED_ROOT" 2>/dev/null && pwd) || fail "SavedVariables directory does not exist: $SAVED_ROOT"
    command -v sed >/dev/null 2>&1 || fail 'sed is required for SavedVariables migration.'
    find "$SAVED_ROOT" -type f -name 'pfQuest.lua' -print | while IFS= read -r legacy_saved; do
      new_saved=$(dirname "$legacy_saved")/KoQuest.lua
      if [ -e "$new_saved" ]; then
        printf '%s\n' "Kept existing KoQuest SavedVariables: $new_saved"
      else
        sed \
          -e 's/pfQuest_confirmedAvailable/KoQuest_confirmedAvailable/g' \
          -e 's/pfQuest_questcache/KoQuest_questcache/g' \
          -e 's/pfQuest_config/KoQuest_config/g' \
          -e 's/pfBrowser_fav/KoBrowser_fav/g' \
          -e 's/pfQuest_history/KoQuest_history/g' \
          -e 's/pfQuest_colors/KoQuest_colors/g' \
          -e 's/pfQuest_server/KoQuest_server/g' \
          -e 's/pfQuest_track/KoQuest_track/g' \
          -e 's#Interface\\\\AddOns\\\\pfQuest#Interface\\\\AddOns\\\\KoQuest#g' \
          "$legacy_saved" > "$new_saved"
        printf '%s\n' "Migrated legacy KoQuest SavedVariables to: $new_saved"
      fi
    done
  else
    printf '%s\n' 'NOTE: pass the SavedVariables directory as argument 2 to migrate beta1.20 settings on Linux.'
  fi
fi

mv "$STAGE/KoQuest" "$TARGET"
installed_new=1
verify_payload "$TARGET"

[ ! -d "$ROLLBACK" ] || remove_private_dir "$ROLLBACK"
[ ! -d "$LEGACY_ROLLBACK" ] || remove_private_dir "$LEGACY_ROLLBACK"
[ ! -d "$STAGE" ] || remove_private_dir "$STAGE"
success=1
printf '%s\n' "DONE: KoQuest $VERSION installed and verified at $TARGET"
printf '%s\n' 'Restart Emberveil completely, then enable KoQuest in the AddOns list.'
