#!/usr/bin/env bash
# gomobile emits macOS-style frameworks (Versions/A/...). iOS uses shallow bundles
# (Info.plist and binary next to each other). Source this file or run flatten_libbox_xcframework.
#
# Some gomobile/sing-box builds ship an empty or stub Info.plist under Versions/A/Resources.
# Xcode then reports "Info.plist ... was empty" after embed. We merge or synthesize a valid
# iOS framework plist at the framework root when the copy is unusable.

# Defaults match sing-box experimental/libbox + gomobile naming (see build_libbox -libname=box → Libbox.framework).
DEFAULT_BUNDLE_ID="io.nekohasekai.libbox"
# Must match NaiveVPN IPHONEOS_DEPLOYMENT_TARGET; gomobile often emits 12.0 and triggers ITMS-90208 if left unchanged.
LIBBOX_MIN_IOS="${LIBBOX_MIN_IOS:-17.0}"

plist_try_read() {
	local plist="$1"
	local key="$2"
	[[ -f "$plist" && -s "$plist" ]] || return 1
	/usr/libexec/PlistBuddy -c "Print :${key}" "$plist" 2>/dev/null || true
}

# Ensure framework root has a non-empty, valid plist with required keys for iOS.
ensure_ios_framework_info_plist() {
	local out="$1"
	local exe_name="$2"
	local src="${3:-}"

	local bid short_ver bundle_ver min_os
	bid="$(plist_try_read "$src" CFBundleIdentifier)"
	short_ver="$(plist_try_read "$src" CFBundleShortVersionString)"
	bundle_ver="$(plist_try_read "$src" CFBundleVersion)"
	min_os="$LIBBOX_MIN_IOS"

	[[ -n "$bid" ]] || bid="$DEFAULT_BUNDLE_ID"
	[[ -n "$short_ver" ]] || short_ver="1.0"
	[[ -n "$bundle_ver" ]] || bundle_ver="1"

	rm -f "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string en" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${exe_name}" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${bid}" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string ${exe_name}" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string FMWK" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${short_ver}" "$out"
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${bundle_ver}" "$out"
	/usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string ${min_os}" "$out"
}

framework_info_plist_ok() {
	local plist="$1"
	local exe_name="$2"
	[[ -f "$plist" && -s "$plist" ]] || return 1
	plutil -lint "$plist" &>/dev/null || return 1
	local pe
	pe="$(plist_try_read "$plist" CFBundleExecutable)"
	[[ -n "$pe" && "$pe" == "$exe_name" ]] || return 1
	[[ -n "$(plist_try_read "$plist" CFBundleIdentifier)" ]] || return 1
	return 0
}

# App Store: embedded framework MinimumOSVersion must match app deployment target (ITMS-90208).
patch_framework_minimum_os() {
	local plist="$1"
	[[ -f "$plist" && -s "$plist" ]] || return 0
	if /usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$plist" &>/dev/null; then
		/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion ${LIBBOX_MIN_IOS}" "$plist"
	else
		/usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string ${LIBBOX_MIN_IOS}" "$plist"
	fi
}

flatten_framework_for_ios() {
	local fw="$1"
	local va="${fw}/Versions/A"
	[[ -d "$va" ]] || return 0

	local tmp
	tmp="$(mktemp -d "${TMPDIR%/}/libbox-fw-XXXXXX")"

	local src_plist="${va}/Resources/Info.plist"
	local exe_name
	exe_name="$(plist_try_read "$src_plist" CFBundleExecutable)"
	if [[ -z "$exe_name" ]]; then
		exe_name="Libbox"
	fi

	if [[ ! -f "${va}/${exe_name}" ]]; then
		local f
		for f in "${va}"/*; do
			[[ -f "$f" ]] || continue
			if file -b "$f" | grep -qi 'mach-o'; then
				exe_name="$(basename "$f")"
				break
			fi
		done
	fi

	if [[ -f "${va}/${exe_name}" ]]; then
		cp "${va}/${exe_name}" "${tmp}/${exe_name}"
	else
		rm -rf "$tmp"
		echo "flatten_framework_for_ios: no Mach-O binary found in $va" >&2
		return 1
	fi

	if [[ -f "$src_plist" ]]; then
		cp "$src_plist" "${tmp}/Info.plist"
	else
		: >"${tmp}/Info.plist"
	fi

	[[ -d "${va}/Headers" ]] && cp -R "${va}/Headers" "${tmp}/Headers"
	[[ -d "${va}/Modules" ]] && cp -R "${va}/Modules" "${tmp}/Modules"

	if ! framework_info_plist_ok "${tmp}/Info.plist" "$exe_name"; then
		ensure_ios_framework_info_plist "${tmp}/Info.plist" "$exe_name" "$src_plist"
	fi

	if ! framework_info_plist_ok "${tmp}/Info.plist" "$exe_name"; then
		rm -rf "$tmp"
		echo "flatten_framework_for_ios: failed to write valid Info.plist for $fw" >&2
		return 1
	fi

	patch_framework_minimum_os "${tmp}/Info.plist"

	rm -rf "$fw"
	mv "$tmp" "$fw"
}

# Fix root Info.plist when the bundle is already shallow (e.g. older flatten left a 0-byte plist).
ensure_shallow_framework_info_plist() {
	local fw="$1"
	[[ -d "${fw}/Versions" ]] && return 0

	local plist="${fw}/Info.plist"
	local exe_name=""
	local f
	for f in "${fw}"/*; do
		[[ -f "$f" ]] || continue
		if file -b "$f" | grep -qi 'mach-o'; then
			exe_name="$(basename "$f")"
			break
		fi
	done
	[[ -n "$exe_name" ]] || return 0

	if ! framework_info_plist_ok "$plist" "$exe_name"; then
		ensure_ios_framework_info_plist "$plist" "$exe_name" "$plist"
	fi
	patch_framework_minimum_os "$plist"
}

flatten_libbox_xcframework_at() {
	local root="$1"
	while IFS= read -r -d '' fw; do
		flatten_framework_for_ios "$fw" || return 1
	done < <(find "$root" -name "*.framework" -type d -print0)
	while IFS= read -r -d '' fw; do
		ensure_shallow_framework_info_plist "$fw" || return 1
	done < <(find "$root" -name "*.framework" -type d -print0)
}
