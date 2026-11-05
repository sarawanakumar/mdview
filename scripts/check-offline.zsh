#!/bin/zsh
# Spec 9.1: mdview and its WebKit processes make no network requests.
#
# Usage, from the repository root, with a build in build/:
#
#     zsh scripts/check-offline.zsh [path/to/mdview.app]
#
# Copies every fixture into build/ (git-ignored), opens them all while
# macOS's nettop records every socket on the machine, edits images.md so it
# reloads with new remote images, then opens a 5 MB file (made by
# scripts/time-open.swift, if it's there). Passes if none of mdview's
# processes ever had a socket: no nettop rows, no lsof entries. It also
# lists the processes nettop did see, as a sign that it was working.

APP=${1:-$PWD/build/mdview.app}
[[ -d $APP && -d fixtures ]] || { print "Run from the repository root, with a built app at $APP."; exit 1 }
OUT=$PWD/build/offline-check-$(date +%s)
mkdir -p $OUT
rsync -a --exclude expected fixtures/ $OUT/files/

pkill -x mdview; sleep 2
before=" ${(j: :)${(f)"$(pgrep -f 'com.apple.WebKit\.')"}} "
nettop -L 60 -s 1 -n -x > $OUT/nettop.csv 2>&1 &
monitor=$!
sleep 1

files=(${(f)"$(find $OUT/files -type f \( -name '*.md' -o -name '*.txt' \) | sort)"})
print "Opening ${#files} files…"
open -a $APP $files --args -ApplePersistenceIgnoreState YES
sleep 15
printf '\n![added later](https://example.com/later.png)\n\n<img src="http://example.org/x.png">\n' >> $OUT/files/images.md
sleep 5
[[ -f build/timing/large.md ]] && open -a $APP $PWD/build/timing/large.md
sleep 10

watched=(${(f)"$(pgrep -x mdview)"})
for pid in ${(f)"$(pgrep -f 'com.apple.WebKit\.')"}; do
    [[ $before == *" $pid "* ]] || watched+=$pid
done
sockets=""
for i in 1 2 3; do
    sockets+=$(lsof -nP -i -a -p ${(j:,:)watched} 2>/dev/null)
    sleep 5
done
wait $monitor
rows=""
for pid in $watched; do rows+=$(grep -E "\.$pid," $OUT/nettop.csv); done
pkill -x mdview

print "Watched ${#watched} processes (mdview and the WebKit processes it started)."
print "nettop saw these other processes, so it was working:"
print "  $(grep -vE '^time|^(tcp|udp)' $OUT/nettop.csv | cut -d, -f2 | sed 's/\.[0-9]*$//' | sort -u | head -8 | tr '\n' ' ')"
if [[ -z $rows && -z $sockets ]]; then
    print "PASS: no sockets and no network rows for any watched process."
else
    print "FAIL:"; print -- $rows; print -- $sockets
    exit 1
fi
