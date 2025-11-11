# Airgapped Marple Deployment

- docker-compose up -d
- Marple Insight: http://localhost
- Marple DB: http://localhost:8000
- minio: http://localhost:9001

- dex:
  authority: http://marple.local:8080
  client: marple-client
  audience: marple-client

-or-

- keycloak
  authority: http://marple.local:8080/realms/marple
  client: marple-client
  audience: account
