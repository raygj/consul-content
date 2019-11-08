`export GATEWAY_URL= <some IP/DNS name>`

`for i in {1..100}; do curl -o /dev/null -s -w "%[http_code]\n" http://${GATEWAY_URL\}/productpage\; done`