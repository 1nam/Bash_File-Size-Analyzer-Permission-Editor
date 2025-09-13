#!/bin/bash

# Prompt for directory
read -rp "Enter directory name: " Dir

CSV_FILE="file_info.csv"
BAR_CHART="file_sizes_bar.png"
LOG_FILE="libreoffice.log"

# Check directory exists
[[ ! -d "$Dir" ]] && { echo "Directory does not exist."; exit 1; }

# Generate CSV
echo "Name,Type,Status,Permissions,SizeKB" > "$CSV_FILE"
for item in "$Dir"/*; do
    [[ ! -e "$item" ]] && continue
    if [[ -f "$item" ]]; then
        Type="File"
        Status="Not empty"
        [[ ! -s "$item" ]] && Status="Empty"
        size_kb=$(( $(stat -c%s "$item") / 1024 ))
        [[ $size_kb -eq 0 ]] && size_kb=1
    elif [[ -d "$item" ]]; then
        Type="Directory"
        count=$(find "$item" -mindepth 1 -maxdepth 1 | wc -l)
        (( count > 0 )) && Status="Contains $count item(s)" || Status="Empty"
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
done
echo "CSV saved to $CSV_FILE"

# Open CSV silently
command -v libreoffice &> /dev/null && libreoffice --calc --norestore --nolockcheck "$CSV_FILE" >"$LOG_FILE" 2>&1 &

# Ask for bar chart
read -rp "Generate bar chart of file sizes? (y/n): " chart_choice
chart_choice=$(echo "$chart_choice" | tr '[:upper:]' '[:lower:]')

if [[ "$chart_choice" == "y" ]] && command -v gnuplot &> /dev/null; then
    # Prepare data: only files with size > 0, sorted descending
    awk -F, 'NR>1 && $5>0 {print $1,$5}' "$CSV_FILE" | sort -k2 -nr > bar_data.txt
    [[ ! -s bar_data.txt ]] && { echo "No files >0 KB. Skipping chart."; exit 0; }

    # Generate bar chart PNG
    gnuplot <<- EOF
        set terminal pngcairo size 1000,600 enhanced font "Arial,10"
        set output "$BAR_CHART"
        set style data histograms
        set style fill solid 1.0 border -1
        set boxwidth 0.8
        set xtics rotate by -45
        set ylabel "Size (KB)"
        set grid ytics

        # Display file sizes above bars
        plot 'bar_data.txt' using 2:xtic(1) title "File Size", \
             '' using 2:2:(stringcolumn(2)) with labels offset 0,1 notitle
EOF

    rm -f bar_data.txt

    [[ -s "$BAR_CHART" ]] && command -v eog &> /dev/null && eog "$BAR_CHART" &
    echo "Bar chart saved to $BAR_CHART and opened in EOG."
fi

# Permission editor
echo
echo "=== File Permission Editor ==="
ls -1 "$Dir"
while true; do
    read -rp "Enter file to modify permissions (or 'exit'): " choice
    [[ "$choice" == "exit" ]] && { clear; break; }
    [[ ! -e "$Dir/$choice" ]] && { echo "File not found"; continue; }
    read -rp "Add or Remove permissions? (A/R): " action
    action=$(echo "$action" | tr '[:lower:]' '[:upper:]')
    echo "Choose permissions (R,W,X):"
    read -rp "Enter: " perms
    perms=$(echo "$perms" | tr '[:lower:]' '[:upper:]')
    chmod_cmd="u"
    [[ "$action" == "A" ]] && chmod_cmd+="+"
    [[ "$action" == "R" ]] && chmod_cmd+="-"
    [[ "$perms" == *"R"* ]] && chmod_cmd+="r"
    [[ "$perms" == *"W"* ]] && chmod_cmd+="w"
    [[ "$perms" == *"X"* ]] && chmod_cmd+="x"
    [[ "$chmod_cmd" != "u+" && "$chmod_cmd" != "u-" ]] && chmod "$chmod_cmd" "$Dir/$choice"
done
