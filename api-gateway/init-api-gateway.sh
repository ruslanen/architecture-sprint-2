#!/bin/bash

public_ip=$(curl -s ifconfig.me)
app1_internal_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq --filter "name=pymongo" | head -n 1))
app2_internal_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq --filter "name=pymongo" | tail -n 1))

echo $public_ip
echo $app1_internal_ip
echo $app2_internal_ip

curl "http://$public_ip:8500/v1/agent/service/register" -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "ID": "svc-a1",
    "Name": "svc-a",
    "Tags": ["sample_web_svc", "v1"],
    "Address": "'$app1_internal_ip'",
    "Port": 8080,
    "Weights": {
      "Passing": 10,
      "Warning": 1
    }
  }'


curl "http://$public_ip:8500/v1/agent/service/register" -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "ID": "svc-a2",
    "Name": "svc-a",
    "Tags": ["sample_web_svc", "v1"],
    "Address": "'$app2_internal_ip'",
    "Port": 8080,
    "Weights": {
      "Passing": 10,
      "Warning": 1
    }
  }'

curl "http://$public_ip:9180/apisix/admin/routes" -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -d '
{
  "id": "consul-web-route",
  "uri": "/*",
  "upstream": {
    "service_name": "svc-a",
    "discovery_type": "consul",
    "type": "roundrobin"
  }
}' | jq