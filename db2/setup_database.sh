echo "setup_database.sh: Creating database. This will take a while, go grab a coffee"
db2 "create database TEST_DB PAGESIZE 32768"
db2 connect to TEST_DB
db2 ACTIVATE DATABASE TEST_DB
echo "setup_database.sh: Creating schema"
db2 "CREATE SCHEMA schema1 authorization db2inst1"
echo "setup_database.sh: Creating tables"
db2 "create table schema1.sample_table(id number, name varchar(20))"