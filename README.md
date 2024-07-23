Sure! Based on the content provided in the GitHub repository [kuluce/mysql-5.7-backup-restore](https://github.com/kuluce/mysql-5.7-backup-restore), here is a rewritten README.md file:

```markdown
# MySQL 5.7 Backup and Restore

This repository provides a comprehensive solution for automating the backup and restore processes of MySQL 5.7 databases using Docker. The scripts included offer full and incremental backup capabilities, as well as the ability to manage historical backups.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
  - [Backup](#backup)
  - [Restore](#restore)
- [Backup Strategy](#backup-strategy)
- [License](#license)

## Overview

This project aims to automate the backup and restore operations for MySQL 5.7 databases deployed in Docker containers. It includes scripts for:
- Full backups
- Incremental backups
- Historical backup management
- Automated restore processes

## Features

- **Full Backup**: Performed weekly to ensure a complete snapshot of the database.
- **Incremental Backup**: Performed daily to capture changes since the last full backup.
- **Historical Backup Management**: Automatically archives and compresses old backups, retaining the last 30 cycles.
- **Automated Restore**: Simplified scripts to restore databases from full and incremental backups.

## Setup

### Prerequisites

- Docker
- MySQL 5.7
- `xtrabackup` installed on the MySQL container
- Proper configuration of MySQL user permissions

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/kuluce/mysql-5.7-backup-restore.git
   cd mysql-5.7-backup-restore
   ```

2. Ensure your MySQL containers are configured correctly and accessible.

## Usage

### Backup

The backup process can be executed using the provided `backup_database.sh` script. It supports full and incremental backups based on the day of the week.

#### Running a Backup

To schedule the backup script via cron, add the following entry to your crontab:
```bash
10 0 * * * /bin/bash /path/to/backup_database.sh backup
```

This will run the backup script at 00:10 every day.

### Restore

The restore process can be executed using the provided `restore_database.sh` script. It supports restoring from full and incremental backups.

#### Running a Restore

1. To restore a full backup:
   ```bash
   /bin/bash /path/to/restore_database.sh full <backup_id>
   ```

2. To restore an incremental backup:
   ```bash
   /bin/bash /path/to/restore_database.sh inc <backup_id>
   ```

## Backup Strategy

The backup strategy implemented in this repository follows these principles:

- **Weekly Full Backups**: Performed every Saturday.
- **Daily Incremental Backups**: Performed every day except Saturday.
- **Historical Backup Management**: Archives and compresses the previous week's full and incremental backups every Saturday, retaining the last 30 cycles.

### Backup Script Details

The `backup_database.sh` script:
- Checks the day of the week and performs the appropriate backup (full or incremental).
- Archives and moves the previous week's backups to a historical directory.
- Logs all operations for troubleshooting and auditing purposes.

### Restore Script Details

The `restore_database.sh` script:
- Handles both full and incremental restores.
- Ensures the target database is stopped before performing the restore.
- Logs all operations for troubleshooting and auditing purposes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
```

This README file provides a comprehensive overview of the project, instructions for setup and usage, and details about the backup strategy. It is designed to be clear and informative for users who want to implement and use the backup and restore scripts provided in the repository.