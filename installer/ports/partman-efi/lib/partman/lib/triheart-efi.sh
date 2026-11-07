# Probe the selected partition directly, including the FAT boot-sector label.
is_ventoy_efi() {
	blkid -p "$1" 2>/dev/null |
		grep -Eq ' (LABEL|LABEL_FATBOOT)="VTOYEFI"( |$)'
}
