#!/bin/bash

if [ "$1" = "cleanup" ]
then
  docker-compose down
  mvn clean
  exit
fi

mvn package || exit 1
if [ ! -e transfer/target/BUILD ] || [ "$(find transfer/target/classes/ -anewer transfer/target/BUILD | grep transfer/target/classes/de )" != "" ]
then
  echo "Rebuilding Docker-Image..."
  docker-compose rm -svf peter ute franz beate klaus
  mvn -f transfer/pom.xml docker:build
  touch transfer/target/BUILD
fi
if [ "$1" = "build" ]; then exit; fi

docker-compose up -d zookeeper kafka

while ! [[ $(docker-compose run --rm kafka zookeeper-shell zookeeper:2181 ls /brokers/ids 2> /dev/null) =~ 1001 ]]; do echo "Waiting for kafka..."; sleep 1; done

docker-compose run --rm kafka kafka-topics --zookeeper zookeeper:2181 --if-not-exists --create --replication-factor 1 --partitions 5 --topic transfers

docker-compose up -d peter ute franz beate klaus

docker-compose run --name transferlog --rm kafka kafka-console-consumer --bootstrap-server kafka:9093 --topic transfers &
while ! [[ $(http 0:8091/actuator/health 2> /dev/null | jq -r .status ) =~ "UP" ]]; do echo "Waiting for peter..."; sleep 1; done

echo '{"id":1,"payer":1,"payee":2, "amount":10}' | http -v :8091/transfers
http --follow :8091/transfers/1
http -v  :8091/transfers id=2 payer=2 payee=1 amount=5
http --follow :8091/transfers/2
http -v  :8091/transfers id=12 payer=2 payee=1 amount=5
http -v  :8091/transfers id=21 payer=2 payee=1 amount=5
http -v  :8091/transfers id=7  payer=2 payee=1 amount=5
http -v  :8091/transfers id=9  payer=2 payee=1 amount=5
http -v  :8091/transfers id=13 payer=2 payee=1 amount=5
http -v  :8091/transfers id=31 payer=2 payee=1 amount=5
http --follow :8091/transfers/12
http --follow :8091/transfers/21
http --follow :8091/transfers/7
http --follow :8091/transfers/9
http --follow :8091/transfers/13
http --follow :8091/transfers/31

docker-compose restart peter ute franz beate klaus
while ! [[ $(http 0:8091/actuator/health 2> /dev/null | jq -r .status ) =~ "UP" ]]; do echo "Waiting for peter..."; sleep 1; done
http --follow :8091/transfers/1
http --follow :8091/transfers/2
http --follow :8091/transfers/12
http --follow :8091/transfers/21
http --follow :8091/transfers/7
http --follow :8091/transfers/9
http --follow :8091/transfers/13
http --follow :8091/transfers/31


docker container stop transferlog
