docker run --rm \
    --network keycloak_default \
    --name keycloak_exporter \
    -v export:/tmp \
    -e KC_DB=postgres \
    -e KC_DB_PASSWORD=password \
    -e KC_DB_USERNAME=marple \
    -e KC_DB_URL=jdbc:postgresql://postgres:5432/marple \
    quay.io/keycloak/keycloak:latest \
    export \
    --realm marple \
    --file /tmp/keycloak-export.json