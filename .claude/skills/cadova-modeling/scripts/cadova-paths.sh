#!/bin/sh
# Prints where the resolved Cadova checkout lives, so its docs, style guide
# and sources can be read for the exact version this package uses.

root="$(cd "$(dirname "$0")/../../../.." && pwd)"
checkout=""

if [ -d "$root/.build/checkouts/Cadova" ]; then
	checkout="$root/.build/checkouts/Cadova"
else
	name="$(basename "$root")"
	for dir in "$HOME"/Library/Developer/Xcode/DerivedData/"$name"-*/SourcePackages/checkouts/Cadova; do
		[ -d "$dir" ] && checkout="$dir" && break
	done
fi

if [ -z "$checkout" ]; then
	echo "Cadova checkout not found. Resolve packages first (swift package resolve, or open the package in Xcode)." >&2
	echo "Online docs: https://cadova.org/docs" >&2
	exit 1
fi

version="$(grep -A6 '"identity" : "cadova"' "$root/Package.resolved" 2>/dev/null | sed -n 's/.*"version" : "\(.*\)".*/\1/p')"

echo "version:     ${version:-unknown}"
echo "checkout:    $checkout"
echo "style guide: $checkout/CadovaStyleGuide.md"
echo "docs:        $checkout/Sources/Cadova/Cadova.docc"
echo "sources:     $checkout/Sources/Cadova"
