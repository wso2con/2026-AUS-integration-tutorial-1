# Sales Data Aggregator

A Ballerina batch job that exports the current day's sales orders from the PizzaHub MySQL database into a CSV file and uploads it to an FTP server. Designed to run once per day (typically end-of-day or early-morning), it produces a date-stamped file ready for downstream reporting, archival, or partner consumption.

This integration is part of the **PizzaHub** sample and demonstrates a classic database-to-file batch ETL pattern in Ballerina.

## Overview

When invoked, the program:

1. Computes today's date (UTC) and uses it to filter and name the output file.
2. Queries the `orders` table for all rows whose `order_date` falls on today.
3. If no rows are found, logs a message and exits without writing a file.
4. Otherwise, builds an in-memory CSV (header row plus one row per order) and uploads it via FTP to `<ftpUploadPath>/sales_YYYY-MM-DD.csv`, overwriting any existing file with the same name.

```
+----------------+        +-----------------------+        +-------------------+
|   MySQL DB     |  SQL   |   sales_data_         |  FTP   |   FTP Server      |
|   (orders)     | -----> |   aggregator          | -----> |   <ftpUploadPath> |
|                |        |   (Ballerina batch)   |        |   sales_YYYY-MM-  |
|                |        |                       |        |   DD.csv          |
+----------------+        +-----------------------+        +-------------------+
```

The program is a one-shot `public function main()` — it runs to completion and exits. Scheduling (cron, systemd timer, Airflow, etc.) is intentionally external.

## Data model

The `orders` table is expected to expose at least the following columns. The Ballerina `Order` record in `types.bal` is mapped 1:1 to this projection.

| Column            | Type        | Notes                              |
| ----------------- | ----------- | ---------------------------------- |
| `order_id`        | INT         | Primary key                        |
| `customer_name`   | VARCHAR     |                                    |
| `customer_email`  | VARCHAR     |                                    |
| `item_name`       | VARCHAR     | Single-item-per-row representation |
| `quantity`        | INT         |                                    |
| `total_price`     | DECIMAL     | Mapped to Ballerina `decimal`      |
| `order_status`    | VARCHAR     | e.g. `CONFIRMED`, `DELIVERED`      |
| `order_date`      | DATE / DATETIME | Filtered with `DATE(order_date) = today` |

The exact SQL is:

```sql
SELECT order_id, customer_name, customer_email, item_name,
       quantity, total_price, order_status, order_date
  FROM orders
 WHERE DATE(order_date) = ?
```

## Output

A CSV file named `sales_YYYY-MM-DD.csv`, uploaded to `<ftpUploadPath>` on the configured FTP server. Existing files at the same path are overwritten (`ftp:OVERWRITE`).

Example file (`sales_2026-05-14.csv`):

```csv
order_id,customer_name,customer_email,item_name,quantity,total_price,order_status,order_date
10293,Mohan,mohan@example.com,Margherita Large,2,38.00,DELIVERED,2026-05-14
10294,Alex,alex@example.com,Pepperoni Medium,1,16.50,CONFIRMED,2026-05-14
```

## Project structure

```
sales_data_aggregator/
├── Ballerina.toml         Package metadata (org, name, version, distribution)
├── Config.toml            Example runtime configuration (gitignored in production)
├── Dependencies.toml      Auto-generated dependency lockfile
├── main.bal               Entry point: query, build CSV, FTP upload
├── types.bal              Order record matching the orders table schema
├── config.bal             Configurable variable declarations
├── connections.bal        MySQL and FTP client declarations
├── functions.bal          (placeholder, currently empty)
├── agents.bal             (placeholder, currently empty)
├── automation.bal         (placeholder, currently empty)
└── data_mappings.bal      (placeholder, currently empty)
```

## Prerequisites

- **Ballerina** `2201.13.4` (Swan Lake) or compatible. Install from [ballerina.io/downloads](https://ballerina.io/downloads/).
- **MySQL** server with the `orders` table populated. The MySQL JDBC driver is pulled in transitively via `ballerinax/mysql.driver` — no manual driver install required.
- **FTP server** with an account that can write to the configured upload path. Plain `FTP` is used (no TLS in the current configuration); use it inside a trusted network or extend `connections.bal` to use `ftp:SFTP` if needed.

## Configuration

All runtime values are supplied via `Config.toml` (or environment variables / CLI flags — see [Ballerina configurable variables](https://ballerina.io/learn/provide-values-to-configurable-variables/)).

```toml
[mohan.sales_data_aggregator]
dbHost = "localhost"
dbPort = 3306
dbUser = "root"
dbPassword = "12345678"
dbName = "pizzahub"
ftpHost = "localhost"
ftpPort = 21
ftpUser = "ftpuser"
ftpPassword = "1234"
ftpUploadPath = "/home/out"
```

| Key             | Purpose                                                        |
| --------------- | -------------------------------------------------------------- |
| `dbHost`        | MySQL host                                                     |
| `dbPort`        | MySQL port                                                     |
| `dbUser`        | MySQL username                                                 |
| `dbPassword`    | MySQL password                                                 |
| `dbName`        | Database containing the `orders` table                         |
| `ftpHost`       | FTP server host                                                |
| `ftpPort`       | FTP server port (typically `21`)                               |
| `ftpUser`       | FTP username                                                   |
| `ftpPassword`   | FTP password                                                   |
| `ftpUploadPath` | Remote directory to upload to (file is appended as a child)    |

`Config.toml` is gitignored by default — do **not** commit production credentials.

## Build and run

From the project root:

```bash
# Build the package
bal build

# Run directly from source
bal run

# Or run the built JAR
java -jar target/bin/sales_data_aggregator.jar
```

To use a non-default config file:

```bash
BAL_CONFIG_FILES=./Config.toml bal run
```

## Scheduling

The program is a single-shot batch job — it does **not** schedule itself. Wire it into your preferred scheduler:

**cron (every day at 23:55 local):**

```cron
55 23 * * * /usr/bin/java -jar /opt/pizzahub/sales_data_aggregator.jar \
    -CBAL_CONFIG_FILES=/etc/pizzahub/Config.toml >> /var/log/pizzahub/sales.log 2>&1
```

**systemd timer**, **Kubernetes CronJob**, **Airflow PythonOperator** invoking the JAR, or a Ballerina `task:JobService` wrapper are all reasonable alternatives.

## Behavior notes

- **Date determination.** The cutoff date is computed from `time:utcNow()` and truncated to `YYYY-MM-DD`. If the job is run shortly after midnight UTC, it will export the new day's (likely empty) orders, not the previous day's. Adjust the date logic or scheduling timezone if your business day is anchored to a non-UTC zone.
- **Empty days.** If the query returns zero rows, the job logs an informational message and exits without creating a file. No empty CSV is uploaded.
- **Overwrites.** Re-running the job on the same day will replace the existing `sales_YYYY-MM-DD.csv` on the FTP server (`ftp:OVERWRITE`). Useful for retries; be aware it discards any earlier upload from the same day.
- **CSV escaping.** Generated by the FTP module's `putCsv` helper, which handles delimiter and newline escaping. Special characters in customer names or item names should round-trip safely; verify against your downstream consumer if it has strict parsing rules.
- **No partial-failure recovery.** The FTP upload is an all-or-nothing call. On failure, the program exits with an error; the next scheduled run will retry. There is no checkpoint or resume.

## Error handling

The `main` function returns `error?`, so any failure — DB connection error, query error, FTP failure — propagates out and terminates the program with a non-zero exit. Errors and successful milestones are emitted via `ballerina/log` as structured log entries (e.g. `count`, `date`, `fileName`, `remotePath`, `rowCount`). Plug into stdout/journald and ship to your log aggregator of choice.

## Local development

A minimal local setup:

1. Run MySQL locally (Docker is easiest):

   ```bash
   docker run --name pizzahub-mysql -e MYSQL_ROOT_PASSWORD=12345678 \
       -e MYSQL_DATABASE=pizzahub -p 3306:3306 -d mysql:8
   ```

2. Create the `orders` table and seed a few rows dated today.

3. Run a local FTP server (e.g. `stilliard/pure-ftpd` Docker image) with credentials matching `Config.toml`.

4. `bal run` — and check the FTP server for `sales_YYYY-MM-DD.csv`.
