#!/bin/bash

CSV_FILE="file_info.csv"
BAR_CHART="file_sizes_bar.png"
LOG_FILE="libreoffice.log"

# Function to truncate filenames for chart
truncate_name() {
    local name="$1"
    if [ ${#name} -gt 25 ]; then
        echo "${name:0:12}...${name: -10}"
    else
        echo "$name"
    fi
}

# 1️⃣ Directory selection
Dir=$(zenity --file-selection --directory --title="Select Directory")
[[ $? -ne 0 ]] && exit 1
[[ ! -d "$Dir" ]] && zenity --error --text="Directory does not exist." && exit 1

# Gather files
items=("$Dir"/*)
total=${#items[@]}
[[ $total -eq 0 ]] && { zenity --info --text="Directory is empty."; exit 1; }

# 2️⃣ Generate CSV with progress
(
count=0
echo "0"
echo "# Generating CSV..."
echo

echo "Name,Type,Status,Permissions,SizeKB" > "$CSV_FILE"
for item in "${items[@]}"; do
    [[ ! -e "$item" ]] && continue
    if [[ -f "$item" ]]; then
        Type="File"
        Status="Not empty"
        [[ ! -s "$item" ]] && Status="Empty"
        size_kb=$(( $(stat -c%s "$item") / 1024 ))
        [[ $size_kb -eq 0 ]] && size_kb=1
    elif [[ -d "$item" ]]; then
        Type="Directory"
        count_items=$(find "$item" -mindepth 1 -maxdepth 1 | wc -l)
        (( count_items > 0 )) && Status="Contains $count_items item(s)" || Status="Empty"
        size_kb=0
    else
        Type="Other"
        Status="N/A"
        size_kb=0
    fi

    perms=""
    [[ -r "$item" ]] && perms+="r" || perms+="-"
    [[ -w "$item" ]] && perms+="w" || perms+="-"
    [[ -x "$item" ]] && perms+="x" || perms+="-"

    echo "\"$item\",\"$Type\",\"$Status\",\"$perms\",$size_kb" >> "$CSV_FILE"

    ((count++))
    percent=$(( count * 100 / total ))
    echo "$percent"
    echo "# Processing: $(basename "$item")"
    sleep 0.05
done
) | zenity --progress --title="Generating CSV" --percentage=0 --auto-close --auto-kill

# Open CSV silently
command -v libreoffice &> /dev/null && libreoffice --calc --norestore --nolockcheck "$CSV_FILE" >"$LOG_FILE" 2>&1 &

# 3️⃣ Generate bar chart
if zenity --question --text="Generate bar chart of file sizes?"; then
    command -v gnuplot &> /dev/null || { zenity --error --text="gnuplot not found."; exit 1; }

    awk -F, 'NR>1 && $5>0 {print $1,$5}' "$CSV_FILE" | sort -k2 -nr > bar_data_full.txt
    [[ ! -s bar_data_full.txt ]] && { zenity --info --text="No files >0 KB. Skipping chart."; exit 0; }

    > bar_data.txt
    while read -r path size; do
        filename=$(basename "$path")
        short=$(truncate_name "$filename")
        echo "$short $size" >> bar_data.txt
    done < bar_data_full.txt

    (
    echo "0"; echo "# Generating Bar Chart..."; sleep 0.5

    gnuplot <<- EOF
        set terminal pngcairo size 1000,600 enhanced font "Arial,10"
        set output "$BAR_CHART"
        set style data histograms
        set style fill solid 1.0 border -1
        set boxwidth 0.8
        set xtics rotate by -45
        set ylabel "Size (KB)"
        set grid ytics
        plot 'bar_data.txt' using 2:xtic(1) title "File Size", \
             '' using 2:2:(stringcolumn(2)) with labels offset 0,1 notitle
EOF

    echo "100"; echo "# Bar chart generated!"
    ) | zenity --progress --title="Bar Chart" --percentage=0 --auto-close --auto-kill

    rm -f bar_data_full.txt bar_data.txt
    [[ -s "$BAR_CHART" ]] && command -v eog &> /dev/null && eog "$BAR_CHART" &
fi

# 4️⃣ Permission editor
while true; do
    files=()
    for f in "$Dir"/*; do
        [[ -f "$f" || -d "$f" ]] && files+=("$(basename "$f")")
    done
    [[ ${#files[@]} -eq 0 ]] && break

    choice=$(zenity --list --title="Select File to Edit Permissions" \
        --text="Choose a file:" \
        --column="File" "${files[@]}" \
        --height=400 --width=600)
    [[ $? -ne 0 || -z "$choice" ]] && break
    full_path="$Dir/$choice"

    action=$(zenity --list --title="Permission Action" --text="Add or Remove permissions?" \
        --column="Action" Add Remove)
    [[ $? -ne 0 || -z "$action" ]] && continue

    current_perms=$(stat -c "%A" "$full_path" | cut -c2-4)
    r_checked="FALSE"; [[ "${current_perms:0:1}" == "r" ]] && r_checked="TRUE"
    w_checked="FALSE"; [[ "${current_perms:1:1}" == "w" ]] && w_checked="TRUE"
    x_checked="FALSE"; [[ "${current_perms:2:1}" == "x" ]] && x_checked="TRUE"

    perms=$(zenity --list --checklist --title="Set Permissions" \
        --text="Select permissions to $action for $choice:" \
        --column="Select" --column="Permission" \
        "$r_checked" "Read" \
        "$w_checked" "Write" \
        "$x_checked" "Execute" \
        --height=200 --width=400)
    [[ $? -ne 0 ]] && continue

    chmod_cmd="u"
    [[ "$action" == "Add" ]] && chmod_cmd+="+"
    [[ "$action" == "Remove" ]] && chmod_cmd+="-"

    [[ $perms == *"Read"* ]] && chmod_cmd+="r"
    [[ $perms == *"Write"* ]] && chmod_cmd+="w"
    [[ $perms == *"Execute"* ]] && chmod_cmd+="x"

    [[ "$chmod_cmd" != "u+" && "$chmod_cmd" != "u-" ]] && chmod "$chmod_cmd" "$full_path"

    zenity --info --text="Permissions updated for $choice"
done

# 5️⃣ Summary dialog
total_files=$(find "$Dir" -maxdepth 1 -type f | wc -l)
total_dirs=$(find "$Dir" -maxdepth 1 -type d | wc -l)
total_size=$(du -sk "$Dir" | awk '{print $1}')

summary_text="Directory: $Dir
Total files: $total_files
Total directories: $total_dirs
Total size: ${total_size}KB
CSV file: $CSV_FILE"

[[ -f "$BAR_CHART" ]] && summary_text+="
Bar chart: $BAR_CHART"

zenity --info --title="Summary Report" --text="$summary_text" --width=500 --height=300
