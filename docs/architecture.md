# Architecture

## Objectif

Fournir un depot GitOps pour deployer une stack LGTM sur un cluster K3S existant. La solution privilegie la simplicite operationnelle: ArgoCD applique les manifests, GitHub Actions valide, Sealed Secrets protege les secrets.

## Flux cible

1. Un operateur importe localement les secrets depuis `C:\XXX`.
2. Les scripts generent des Kubernetes Secrets temporaires dans `secrets/tmp/`.
3. `kubeseal` chiffre ces Secrets avec la cle publique du controller Sealed Secrets du cluster.
4. Seuls les fichiers `SealedSecret` dans `secrets/sealed/` sont versionnes.
5. ArgoCD synchronise les Applications depuis `gitops/argocd/app-of-apps/root-app.yaml`.

## Composants

- ArgoCD: moteur GitOps principal.
- Grafana: UI, dashboards, datasources.
- Loki: stockage et requetes logs.
- Mimir: stockage et requetes metriques Prometheus.
- Tempo: traces distribuees.
- Alloy: collecte logs, metriques, traces et routage vers Loki/Mimir/Tempo.
- Traefik: exposition HTTPS de Grafana.
- Kyverno: garde-fous Kubernetes.
- Sealed Secrets: chiffrement des secrets stockes dans Git.

## Hypotheses

- Le cluster K3S existe et `kubectl` y accede.
- Une StorageClass compatible existe deja.
- Traefik est installe par K3S ou deploye separement.
- Le repository GitHub sera `https://github.com/TechApple/Deploy_LGTM`.
- Le namespace d'observabilite est `observability`.

## Decisions

- Pas d'OpenStack, OpenTofu, ClusterAPI, Crossplane, GitLab CI, Vault/OpenBao ou External Secrets Operator dans le MVP.
- Terraform ne cree pas le cluster Kubernetes.
- Les deploiements production passent par ArgoCD, pas par GitHub Actions.
- Keycloak reste une option phase 2.
