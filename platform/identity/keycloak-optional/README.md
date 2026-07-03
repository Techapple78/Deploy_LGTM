# Keycloak optional

Keycloak est hors MVP. Il devient pertinent quand Grafana doit etre integre au SSO.

Phase 2 recommandee:

1. Deployer Keycloak avec stockage persistant et sauvegardes.
2. Declarer un client OIDC Grafana.
3. Stocker client secret avec Sealed Secrets.
4. Activer `auth.generic_oauth` dans les values Grafana.
5. Tester groupes, roles et rupture de session.
