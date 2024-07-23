# MySQL 5.7 双向同步

## 1. 环境描述

- 主库1: db1
- 主库2: db2

为了方便，使用了两个 Docker 容器作为测试环境，docker-compose.yml 配置如下：

```yaml
version: '3.7'
services:
  db1:
    image: mysql:5.7
    container_name: db1
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: db1
      MYSQL_USER: user1
      MYSQL_PASSWORD: root
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - ./db1:/var/lib/mysql
      - /etc/localtime:/etc/localtime:ro

  db2:
    image: mysql:5.7
    container_name: db2
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: db2
      MYSQL_USER: user2
      MYSQL_PASSWORD: root
      TZ: Asia/Shanghai
    ports:
      - "3307:3306"
    volumes:
      - ./db2:/var/lib/mysql
      - /etc/localtime:/etc/localtime:ro
```

通过以下命令验证数据库版本：

```bash
docker exec -it db1 mysql -uroot -proot -e "SELECT VERSION();"
docker exec -it db2 mysql -uroot -proot -e "SELECT VERSION();"
```

## 2. 创建同步用户

在两个数据库服务器上创建同步用户，授予 `REPLICATION SLAVE` 权限。

- 在 db1 上创建同步用户 repl：

```bash
docker exec -it db1 mysql -uroot -proot -e "GRANT REPLICATION SLAVE, SUPER, REPLICATION CLIENT ON *.* TO 'repl'@'%' IDENTIFIED BY 'repl';"
```

- 在 db2 上创建同步用户 repl：

```bash
docker exec -it db2 mysql -uroot -proot -e "GRANT REPLICATION SLAVE, SUPER, REPLICATION CLIENT ON *.* TO 'repl'@'%' IDENTIFIED BY 'repl';"
```

## 3. 添加数据库的主从配置

### db1 的配置文件：

```bash
cat > conf1/mysqld.cnf <<EOF
[mysqld]
server-id = 1
log-bin = binlog
log_slave_updates = 1
sync_binlog = 1
auto_increment_offset = 1
auto_increment_increment = 2
EOF
```

### db2 的配置文件：

```bash
cat > conf2/mysqld.cnf <<EOF
[mysqld]
server-id = 2
log-bin = binlog
log_slave_updates = 1
sync_binlog = 1
auto_increment_offset = 2
auto_increment_increment = 2
EOF
```

说明：

- **server-id**：每个 MySQL 服务器在复制集群中都需要一个唯一的服务器 ID。这个 ID 用于标识不同的 MySQL 实例。
- **log-bin**: 启用二进制日志记录，并指定二进制日志文件的名称为 'binlog'。二进制日志用于记录所有更改数据的 SQL 语句，主要用于复制和数据恢复。
- **log_slave_updates**: 启用从服务器记录从主服务器接收到的更新到其自己的二进制日志。这对于级联复制很有用（从服务器也可以作为其他服务器的主服务器）。
- **sync_binlog**: 设置 sync_binlog = 1 确保每次事务提交时，MySQL 都会将二进制日志同步到磁盘。这可以确保数据的一致性和可靠性，但可能会对性能有一定影响。
- **auto_increment_offset**: 设置自动递增列的起始值，常用于主主复制（双主复制）环境以避免冲突。在这种配置下，两个服务器的 auto_increment_offset 值不同以确保唯一性。 db1设置为1，db2设置为2
- **auto_increment_increment**: 设置自动递增列的步长，常用于主主复制（双主复制）环境。在这种配置下，两个服务器的 auto_increment_increment 值相同，以确保每个服务器分配不同的自增值。

## 4. 同步配置文件并重启容器

更新 docker-compose.yml：

```yaml
version: '3.7'
services:
  db1:
    image: mysql:5.7
    container_name: db1
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: db1
      MYSQL_USER: user1
      MYSQL_PASSWORD: root
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - ./db1:/var/lib/mysql
      - ./conf1:/etc/mysql/mysql.conf.d
      - /etc/localtime:/etc/localtime:ro

  db2:
    image: mysql:5.7
    container_name: db2
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: db2
      MYSQL_USER: user2
      MYSQL_PASSWORD: root
      TZ: Asia/Shanghai
    ports:
      - "3307:3306"
    volumes:
      - ./db2:/var/lib/mysql
      - ./conf2:/etc/mysql/mysql.conf.d
      - /etc/localtime:/etc/localtime:ro
```

重启容器：

```bash
docker-compose down
docker-compose up -d
```

检查主库状态：

```bash
docker exec -it db1 mysql -uroot -proot -e "SHOW MASTER STATUS\G"
docker exec -it db2 mysql -uroot -proot -e "SHOW MASTER STATUS\G"
```

## 5. 设置同步并启动从库

### 在 db1 和 db2 上配置主从同步

- 在 db1 上配置：

```bash
docker exec -it db1 mysql -uroot -proot -e "
CHANGE MASTER TO MASTER_HOST='db2', MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_LOG_FILE='binlog.000001', MASTER_LOG_POS=154;
START SLAVE;"
```

- 在 db2 上配置：

```bash
docker exec -it db2 mysql -uroot -proot -e "
CHANGE MASTER TO MASTER_HOST='db1', MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_LOG_FILE='binlog.000001', MASTER_LOG_POS=154;
START SLAVE;"
```

### 查询 slave 状态

- 在 db1 上查询：

```bash
docker exec -it db1 mysql -uroot -proot -e "SHOW SLAVE STATUS\G"
```

- 在 db2 上查询：

```bash
docker exec -it db2 mysql -uroot -proot -e "SHOW SLAVE STATUS\G"
```

## 6. 测试同步

### 测试 db1 同步到 db2

- 在 db1 上创建数据库和表，并插入数据：

```bash
docker exec -it db1 mysql -uroot -proot -e "
CREATE DATABASE ethan;
USE ethan;
CREATE TABLE tbl_users (id INT, name VARCHAR(32));
INSERT INTO tbl_users VALUES (1, 'ethan');"
```

- 在 db2 上验证：

```bash
docker exec -it db2 mysql -uroot -proot -e "SELECT * FROM ethan.tbl_users;"
```

### 测试 db2 同步到 db1

- 在 db2 上创建数据库和表，并插入数据：

```bash
docker exec -it db2 mysql -uroot -proot -e "
CREATE DATABASE ethan2;
USE ethan2;
CREATE TABLE tbl_users (id INT, name VARCHAR(32));
INSERT INTO tbl_users VALUES (2, 'ethan2');"
```

- 在 db1 上验证：

```bash
docker exec -it db1 mysql -uroot -proot -e "SELECT * FROM ethan2.tbl_users;"
```