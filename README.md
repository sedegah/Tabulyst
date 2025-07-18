# Tabulyst

**Tabulyst** is a command-line CSV utility written in Haskell. It enables users to explore, summarize, filter, generate SQL schemas, and print CSV data directly from the terminal.


Created by [@sedegah](https://github.com/sedegah)

---

## Features

- Load and display CSV file structure
- Print column-wise summaries
- Filter rows by column-value pairs
- Infer SQL table schemas from CSV data
- Save schema to `.sql` files
- Print rows cleanly to the terminal

---

## Installation

### Prerequisites

- [Haskell Toolchain](https://www.haskell.org/platform/) (GHC 9.6 or later)
- [`cabal-install`](https://www.haskell.org/cabal/)

### Build

```bash
git clone https://github.com/sedegah/Tabulyst.git
cd Tabulyst
cabal update
cabal build
````

---

## Usage

### Basic Format

```bash
Tabulyst <csv-path> [--summary <Column>] [--filter <Column=Value>] [--sql-schema [TableName]] [--print]
```

Run the app via Cabal:

```bash
cabal run Tabulyst -- "<csv-path>" [options]
```

---

## Commands Overview

| Command                                          | Description                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------ |
| `Tabulyst <file>`                                | Display number of rows and column names                            |
| `Tabulyst <file> --summary <Column>`             | Show all values from the specified column                          |
| `Tabulyst <file> --filter <Column=Value>`        | Filter rows by exact match; saves output as `filtered_<file>`      |
| `Tabulyst <file> --sql-schema`                   | Generate SQL `CREATE TABLE` schema as `my_table.sql`               |
| `Tabulyst <file> --sql-schema <CustomTableName>` | Generate schema with the given table name and save to `<name>.sql` |
| `Tabulyst <file> --print`                        | Print all CSV rows, column-aligned                                 |

---

## Example Usage

Replace `<file>` with the path to your CSV file:

```bash
# View summary of the CSV structure
cabal run Tabulyst -- "data.csv"

# Print all values from a specific column
cabal run Tabulyst -- "data.csv" --summary Department

# Filter rows where Department = HR
cabal run Tabulyst -- "data.csv" --filter Department=HR

# Generate SQL schema with default table name (my_table)
cabal run Tabulyst -- "data.csv" --sql-schema

# Generate SQL schema with custom table name
cabal run Tabulyst -- "data.csv" --sql-schema Employees

# Print all rows in the CSV file
cabal run Tabulyst -- "data.csv" --print
```

---

## Output Files

* `filtered_<filename>.csv` — Contains filtered results based on column criteria.
* `<TableName>.sql` — Auto-generated SQL `CREATE TABLE` script based on column types.

---

## Schema Inference Rules

* Uses first 100 rows to determine column types
* Assigns `INTEGER`, `REAL`, or `TEXT` based on content
* Marks fields `NOT NULL` if no empty values exist
* Detects `id` column (case-insensitive) and marks as `PRIMARY KEY`

Example schema output:

```sql
CREATE TABLE Employees (
  ID INTEGER NOT NULL PRIMARY KEY,
  Name TEXT NOT NULL,
  Age INTEGER NOT NULL,
  Department TEXT NOT NULL
);
```

---

## License

MIT License

---

## Author

GitHub: [sedegah](https://github.com/sedegah)

