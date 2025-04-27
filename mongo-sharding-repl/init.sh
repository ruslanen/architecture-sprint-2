#!/bin/bash

execute_command() {
    echo "\n[INFO] Выполняется: $1"
    eval "$1"
    echo "[INFO] Завершено."
}

# Инициализация конфигурационного сервера
execute_command "docker exec -it configSrv mongosh --eval '
  rs.initiate(
    {
      _id : \"config_server\",
      configsvr: true,
      members: [
        { _id : 0, host : \"173.17.0.6:27017\" }
      ]
    }
  );
'"

# Проверка статуса конфигурационного сервера
execute_command "docker exec -it configSrv mongosh --eval 'rs.status()'"

# Инициализация шарда 1
execute_command "docker exec -it mongodb_shard1_a mongosh --port 27018 --eval '
  rs.initiate(
    {
      _id : \"shard1\",
      members: [
        { _id : 0, host : \"173.17.0.8:27018\" },
        { _id : 1, host : \"173.17.0.9:27019\" },
        { _id : 2, host : \"173.17.0.10:27020\" }
      ]
    }
  );
'"

# Инициализация шарда 2
execute_command "docker exec -it mongodb_shard2_a mongosh --port 27021 --eval '
  rs.initiate(
    {
      _id : \"shard2\",
      members: [
        { _id : 0, host : \"173.17.0.11:27021\" },
        { _id : 1, host : \"173.17.0.12:27022\" },
        { _id : 2, host : \"173.17.0.13:27023\" }
      ]
    }
  );
'"

# Настройка шардирования
execute_command "docker exec -it mongos_router mongosh --port 27016 --eval '
  sh.addShard(\"shard1/173.17.0.8:27018,173.17.0.9:27019,173.17.0.10:27020\");
  sh.addShard(\"shard2/173.17.0.11:27021,173.17.0.12:27022,173.17.0.13:27023\");
  sh.enableSharding(\"somedb\");
  sh.shardCollection(\"somedb.helloDoc\", { \"name\" : \"hashed\" });

  var db = connect(\"mongodb://mongos_router:27016/somedb\");

  for (var i = 0; i < 1000; i++) {
    db.helloDoc.insert({ age: i, name: \"ly\" + i });
  }

  var count = db.helloDoc.countDocuments();
  print(\"Document count: \" + count);
'"

echo "\n[INFO] Инициализация MongoDB завершена."