# File Size Analyzer & Permission Editor

A Bash script to **analyze files in a directory**, generate a **CSV report**, 

visualize **file sizes in a bar chart**, and interactively **modify file permissions**.

The script highlights **largest files**, showing actual sizes, and provides a smooth workflow in the terminal.

---

## Features

* Generate a **CSV file** containing:

  * File name
  * Type (File/Directory/Other)
  * Status (Empty / Not Empty / Contains items)
  * Permissions (Read, Write, Execute)
  * Size in KB

* Generate a **bar chart** of file sizes:

  * Largest files appear as the tallest bars
  * File sizes labeled on top of each bar
  * Opens automatically in **EOG**

* **Interactive permission editor**:

  * Add or remove **Read (R), Write (W), Execute (X)** permissions
  * Apply changes per file
  * Option to exit and clear terminal

* Clean terminal output; logs LibreOffice warnings to a separate log file

---

## Requirements

* **GNU Bash**
* **GNU coreutils** (`stat`, `awk`, `find`, `sort`)
* **Gnuplot** (for generating charts)
* **EOG** (Eye of GNOME) to view charts
* **LibreOffice Calc** (optional) for CSV viewing

---

## Usage

1. Clone or download the script:

```bash
git clone https://github.com/1nam/Bash_File-Size-Analyzer-Permission-Editor/tree/main
cd Bash_File-Size-Analyzer-Permission-Editor
```

2. Make the script executable:

```bash
chmod +x Analyzer-Permission-Editor.sh
```

3. Run the script:

```bash
./Analyzer-Permission-Editor.sh
```

4. Follow the prompts:

   * Enter the directory to analyze
   * Choose whether to generate a bar chart
   * Use the permission editor to modify file permissions

---

## Example Output

**CSV File (`file_info.csv`):**

| Name      | Type      | Status           | Permissions | SizeKB |
| --------- | --------- | ---------------- | ----------- | ------ |
| file1.txt | File      | Not empty        | rw-         | 1024   |
| file2.log | File      | Empty            | r--         | 1      |
| subdir    | Directory | Contains 3 items | r-x         | 0      |

**Bar Chart (`file_sizes_bar.png`):**

* Largest files appear as tallest bars
* File sizes labeled above each bar
* Opens automatically in **EOG**

---

## Notes

* Only files with size > 0 KB are included in the chart
* Permission changes affect the **user owner** (`u+r`, `u-w`, etc.)
* Temporary files for chart generation are automatically removed

: i included a whiptail & zenity gui version that can be ran solo.
---

## License

This project is released under the **MIT License**.
