BEGIN { RS = "[\r\n]" }

function emit(phase, position, detail) {
	printf "%s\t%d\t%s\n", phase, position, detail
	fflush()
}

{
	# A pacman terminal redraw ends with a carriage return and may include
	# cursor movement sequences even with color disabled.
	gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
	gsub(/^[[:space:]]+|[[:space:]]+$/, "")
}

/^$/ { next }
/^:: Synchronizing package databases/ { emit("prepare", 1, ""); next }
/^:: Retrieving packages/ {
	downloading = 1
	aggregate = 0
	emit("download", 5, "")
	next
}
/^:: Processing package changes/ { emit("apply", 70, ""); next }
/^:: Running post-transaction hooks/ {
	hooks = 1
	emit("hooks", 95, "")
	next
}

{
	percent = $NF ~ /^[0-9]+%$/ ? $NF + 0 : -1
	count = ""
	if (match($0, /\([[:space:]]*[0-9]+\/[[:space:]]*[0-9]+\)/)) {
		count = substr($0, RSTART + 1, RLENGTH - 2)
		gsub(/[[:space:]]/, "", count)
	}
	if (percent >= 0 && $0 ~ /\[[^]]*\]/) {
		if (downloading && $1 == "Total" && count != "") {
			aggregate = 1
			split(count, items, "/")
			if (items[2] == 0) next
			# Pacman's percentage measures bytes. Track completed packages
			# in the label and this part of the overall bar.
			if (items[1] == items[2] && percent == 100) {
				emit("download-finished", 55, "")
			} else {
				position = 5 + int(50 * items[1] / items[2])
				detail = count " (" int(100 * items[1] / items[2]) "%)"
				if (match($0, /[[:space:]][0-9]+([.][0-9]+)?[[:space:]]+([KMGTPEZY]i)?B\/s/)) {
					rate = substr($0, RSTART + 1, RLENGTH - 1)
					sub(/[[:space:]]+/, " ", rate)
					detail = detail ", " rate
				}
				emit("download-total", position, detail)
			}
		} else if ($0 ~ /^\(/ && count != "") {
			downloading = 0
			operation = $0
			sub(/^\([^)]*\)[[:space:]]*/, "", operation)
			if (operation ~ /^(installing|upgrading|reinstalling|downgrading|removing) /) {
				split(operation, fields, /[[:space:]]+/)
				split(count, items, "/")
				if (items[2] == 0) next
				emit("apply", 70 + 25 * (items[1] - 1 + percent / 100) / items[2], count "  " fields[2])
				if (percent == 100) emit("log", 0, count " " fields[1] " " fields[2])
			} else {
				start = 55
				if (operation ~ /^checking package integrity/) start = 58
				if (operation ~ /^loading package files/) start = 61
				if (operation ~ /^checking for file conflicts/) start = 64
				if (operation ~ /^checking available disk space/) start = 67
				emit("verify", start + 3 * percent / 100, count "  " percent "%")
			}
		} else if (downloading && !aggregate) {
			emit("download", 5, $1)
		}
		next
	}
	if (hooks && count != "") {
		detail = $0
		sub(/^\([^)]*\)[[:space:]]*/, "", detail)
		emit("hooks", 95, count "  " detail)
	}
	emit("log", 0, $0)
}
