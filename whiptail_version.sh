#!/bin/bash

CSV_FILE="file_info.csv"
BAR_CHART="file_sizes_bar.png"
LOG_FILE="libreoffice.log"

# 1️⃣ Prompt for directory
Dir=$(whiptail --inputbox "Enter directory name:" 10 60 3>&1 1>&2 2>&3)
[[ $? -ne 0 ]] && exit 1  # Cancel pressed

# Check directory exists
if [[ ! -d "$Dir" ]]; then
    whiptail --msgbox "Directory does not exist." 10 40
    exit 1
fi

# Gather files
items=("$Dir"/*)
total=${#items[@]}
[[ $total -eq 0 ]] && { whiptail --msgbox "Directory is empty." 10 40; exit 1; }

# 2️⃣ Generate CSV with progress
(
echo 0
echo "XXX"
echo "Generating CSV..."
echo "XXX"

echo "Name,Type,Status,Permissions,SizeKB" > "$CSV_FILE"
count=0
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
    echo $percent
    echo "XXX"
    echo "Processing: $(basename "$item") ($percent%)"
    echo "XXX"
    sleep 0.05
done
) | whiptail --title "Generating CSV" --gauge "Please wait..." 10 70 0

# Open CSV silently
command -v libreoffice &> /dev/null && libreoffice --calc --norestore --nolockcheck "$CSV_FILE" >"$LOG_FILE" 2>&1 &

# 3️⃣ Generate bar chart
if whiptail --yesno "Generate bar chart of file sizes?" 10 50; then
    if ! command -v gnuplot &> /dev/null; then
        whiptail --msgbox "gnuplot not found. Cannot generate chart." 10 50
        exit 1
    fi

    # Prepare data: files with size >0
    awk -F, 'NR>1 && $5>0 {print $1,$5}' "$CSV_FILE" | sort -k2 -nr > bar_data_full.txt
    [[ ! -s bar_data_full.txt ]] && { whiptail --msgbox "No files >0 KB. Skipping chart." 10 50; exit 0; }

    # Truncate long filenames in bash
    > bar_data.txt
    while read -r path size; do
        filename=$(basename "$path")
        if [ ${#filename} -gt 25 ]; then
            short="${filename:0:12}...${filename: -10}"
        else
            short="$filename"
        fi
        echo "$short $size" >> bar_data.txt
    done < bar_data_full.txt

    (
    echo 0
    echo "XXX"
    echo "Generating Bar Chart..."
    echo "XXX"

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

    rm -f bar_data_full.txt bar_data.txt

    echo 100
    echo "XXX"
    echo "Bar chart generated!"
    echo "XXX"
    ) | whiptail --title "Bar Chart" --gauge "Please wait..." 10 70 0

    [[ -s "$BAR_CHART" ]] && command -v eog &> /dev/null && eog "$BAR_CHART" &
fi

# 4️⃣ Permission editor
while true; do
    files=()
    for f in "$Dir"/*; do
        files+=("$(basename "$f")" "")
    done

    choice=$(whiptail --title "File Permission Editor" --menu "Select file to modify (Cancel to exit):" 20 60 10 "${files[@]}" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && break

    full_path="$Dir/$choice"

    action=$(whiptail --title "Permission Action" --menu "Add or Remove permissions?" 15 50 2 \
        A "Add" R "Remove" 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && continue

    # Current permissions
    current_perms=$(stat -c "%A" "$full_path" | cut -c2-4)
    r_checked="OFF"; [[ "${current_perms:0:1}" == "r" ]] && r_checked="ON"
    w_checked="OFF"; [[ "${current_perms:1:1}" == "w" ]] && w_checked="ON"
    x_checked="OFF"; [[ "${current_perms:2:1}" == "x" ]] && x_checked="ON"

    # Checkbox dialog
    perms=$(whiptail --title "Set Permissions" --checklist "Select permissions to $action for $choice:" 15 50 5 \
        R "Read" $r_checked \
        W "Write" $w_checked \
        X "Execute" $x_checked 3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && continue

    # Build chmod command
    chmod_cmd="u"
    [[ "$action" == "A" ]] && chmod_cmd+="+"
    [[ "$action" == "R" ]] && chmod_cmd+="-"

    [[ $perms == *"R"* ]] && chmod_cmd+="r"
    [[ $perms == *"W"* ]] && chmod_cmd+="w"
    [[ $perms == *"X"* ]] && chmod_cmd+="x"

    [[ "$chmod_cmd" != "u+" && "$chmod_cmd" != "u-" ]] && chmod "$chmod_cmd" "$full_path"

    whiptail --msgbox "Permissions updated for $choice" 10 50
done
