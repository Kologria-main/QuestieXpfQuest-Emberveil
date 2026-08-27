#!/bin/sh
set -eu

VERSION='2.0.0-beta1.21'
SCRIPT_DIR=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
SOURCE_ROOT="$SCRIPT_DIR/addon"
MANAGED_ADDONS='pfQuest pfQuest_Locale_deDE pfQuest_Locale_esES pfQuest_Locale_frFR pfQuest_Locale_koKR pfQuest_Locale_ptBR pfQuest_Locale_ruRU pfQuest_Locale_zhCN pfQuest_Locale_zhTW'
MANIFEST="$SCRIPT_DIR/installer/payload-manifest.sha256"

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

command -v sha256sum >/dev/null 2>&1 ||
  fail 'sha256sum is required to verify the offline payload.'
if [ -x /usr/bin/find ]; then
  FIND_BIN=/usr/bin/find
elif [ -x /bin/find ]; then
  FIND_BIN=/bin/find
else
  FIND_BIN=$(command -v find 2>/dev/null) || fail 'find is required to verify the offline payload.'
fi
[ -d "$SOURCE_ROOT" ] || fail "Missing payload: $SOURCE_ROOT"
[ -f "$MANIFEST" ] || fail "Missing checksum manifest: $MANIFEST"
for addon_name in $MANAGED_ADDONS; do
  [ -d "$SOURCE_ROOT/$addon_name" ] || fail "Missing managed addon: $addon_name"
done

verify_payload() {
  verify_root=$1
  verify_count=0
  verify_actual_count=0

  while IFS= read -r verify_line || [ -n "$verify_line" ]; do
    case "$verify_line" in ''|'#'*) continue ;; esac
    verify_hash=${verify_line%% *}
    verify_rel=${verify_line#*addon/}
    case "$verify_hash" in *[!0-9A-Fa-f]*|'') fail 'Invalid manifest hash.' ;; esac
    [ "${#verify_hash}" -eq 64 ] || fail 'Invalid manifest hash length.'
    case "$verify_rel" in ''|/*|../*|*/../*|*/..) fail "Unsafe manifest path: $verify_rel" ;; esac
    case "$verify_rel" in
      pfQuest/*|pfQuest_Locale_deDE/*|pfQuest_Locale_esES/*|pfQuest_Locale_frFR/*|pfQuest_Locale_koKR/*|pfQuest_Locale_ptBR/*|pfQuest_Locale_ruRU/*|pfQuest_Locale_zhCN/*|pfQuest_Locale_zhTW/*) ;;
      *) fail "Manifest references an unmanaged addon: $verify_rel" ;;
    esac
    verify_file="$verify_root/$verify_rel"
    [ -f "$verify_file" ] || fail "Payload is missing: $verify_rel"
    verify_actual=$(sha256sum "$verify_file" | awk '{print $1}')
    [ "$verify_actual" = "$verify_hash" ] || fail "Checksum mismatch: $verify_rel"
    verify_count=$((verify_count + 1))
  done < "$MANIFEST"

  [ "$verify_count" -ge 250 ] || fail "Manifest is unexpectedly small: $verify_count files"
  for verify_name in $MANAGED_ADDONS; do
    verify_name_count=$("$FIND_BIN" "$verify_root/$verify_name" -type f | wc -l | tr -d ' ')
    verify_actual_count=$((verify_actual_count + verify_name_count))
  done
  [ "$verify_actual_count" = "$verify_count" ] ||
    fail "Payload file count mismatch: expected $verify_count, found $verify_actual_count"

  for verify_name in $MANAGED_ADDONS; do
    if "$FIND_BIN" "$verify_root/$verify_name" -type f \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.com' \
        -o -iname '*.scr' -o -iname '*.bat' -o -iname '*.cmd' -o -iname '*.ps1' \) | grep -q .; then
      fail 'Executable content was found inside the addon payload.'
    fi
  done
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

[ "$ADDONS" != "$SOURCE_ROOT" ] || fail 'Source and installation target resolve to the same path.'
TOKEN="$$-$(date +%s)"
STAGE="$ADDONS/.koquest-stage-$TOKEN"
ROLLBACK_ROOT="$ADDONS/.koquest-rollback-$TOKEN"
STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
BACKUP_ROOT="$STATE_HOME/koquest/backups/$(date +%Y%m%d-%H%M%S)-$TOKEN"
installed_names=''
moved_old_names=''
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
  rollback_ok=1
  if [ "$success" -ne 1 ]; then
    for cleanup_name in $installed_names; do
      cleanup_target="$ADDONS/$cleanup_name"
      case "$cleanup_name" in
        pfQuest|pfQuest_Locale_*) rm -rf -- "$cleanup_target" 2>/dev/null || rollback_ok=0 ;;
      esac
    done
    for cleanup_name in $moved_old_names; do
      cleanup_rollback="$ROLLBACK_ROOT/$cleanup_name"
      cleanup_target="$ADDONS/$cleanup_name"
      if [ -d "$cleanup_rollback" ] && [ ! -e "$cleanup_target" ]; then
        mv "$cleanup_rollback" "$cleanup_target" 2>/dev/null || rollback_ok=0
      fi
    done
    if [ -n "$moved_old_names" ] && [ "$rollback_ok" -eq 1 ]; then
      printf '%s\n' 'Previous KoQuest folders restored.' >&2
    fi
  fi
  [ ! -d "$STAGE" ] || remove_private_dir "$STAGE"
  if [ -d "$ROLLBACK_ROOT" ] && { [ "$success" -eq 1 ] || [ "$rollback_ok" -eq 1 ]; }; then
    remove_private_dir "$ROLLBACK_ROOT"
  elif [ -d "$ROLLBACK_ROOT" ]; then
    printf '%s\n' "Rollback data preserved at: $ROLLBACK_ROOT" >&2
  fi
  exit "$cleanup_status"
}
trap cleanup EXIT HUP INT TERM

printf '%s\n' "KoQuest offline installer $VERSION"
verify_payload "$SOURCE_ROOT"
mkdir "$STAGE"
for addon_name in $MANAGED_ADDONS; do
  cp -a "$SOURCE_ROOT/$addon_name" "$STAGE/$addon_name"
done
verify_payload "$STAGE"

backup_ready=0
for addon_name in $MANAGED_ADDONS; do
  target="$ADDONS/$addon_name"
  if [ -d "$target" ]; then
    if [ "$backup_ready" -eq 0 ]; then
      mkdir -p "$BACKUP_ROOT"
      mkdir "$ROLLBACK_ROOT"
      backup_ready=1
    fi
    cp -a "$target" "$BACKUP_ROOT/$addon_name"
    mv "$target" "$ROLLBACK_ROOT/$addon_name"
    moved_old_names="$moved_old_names $addon_name"
  elif [ -e "$target" ]; then
    fail "Target exists but is not a directory: $target"
  fi
done
[ "$backup_ready" -eq 0 ] || printf '%s\n' "Existing KoQuest folders backed up to: $BACKUP_ROOT"

for addon_name in $MANAGED_ADDONS; do
  mv "$STAGE/$addon_name" "$ADDONS/$addon_name"
  installed_names="$installed_names $addon_name"
done
verify_payload "$ADDONS"

success=1
[ ! -d "$ROLLBACK_ROOT" ] || remove_private_dir "$ROLLBACK_ROOT"
[ ! -d "$STAGE" ] || remove_private_dir "$STAGE"
printf '%s\n' "DONE: KoQuest $VERSION installed and verified at $ADDONS"
printf '%s\n' 'Restart Emberveil completely, then enable pfQuest in the AddOns list. Locale packs load on demand.'
