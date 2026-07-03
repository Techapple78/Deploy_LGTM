# Rapport Phase 4 - Premiere synchronisation GitOps LGTM

Date: 2026-07-03

## Objectif

Appliquer l'app-of-apps ArgoCD `deploy-lgtm-root` depuis le depot `Techapple78/Deploy_LGTM` et obtenir une premiere synchronisation GitOps de la plateforme LGTM.

## Actions realisees

- Ajout du depot prive GitHub dans ArgoCD via un Secret Kubernetes local, non versionne dans Git.
- Application de `gitops/argocd/app-of-apps/root-app.yaml`.
- Synchronisation initiale des applications enfants ArgoCD.
- Stabilisation Kyverno via une application dediee aux CRD en Server-Side Apply.
- Stabilisation Sealed Secrets avec `releaseName: sealed-secrets-controller`.
- Ajout du SealedSecret `grafana-admin`.
- Simplification Mimir pour un profil MVP sans Kafka, MinIO, zone-aware replication ni rollout webhooks.
- Simplification Loki pour retirer les caches Memcached.

## Commits Phase 4

- `75b4e47` - Stabilisation de la premiere sync LGTM.
- `e27c7ae` - Gestion GitOps des CRD Kyverno en Server-Side Apply.
- `0ea2684` - Secret Grafana scelle et correction Mimir.
- `4508b8c` - Desactivation des webhooks rollout Mimir pour le MVP.

## Etat observe avant incident API

Applications saines observees:

- `deploy-lgtm-root`: `Synced/Healthy`
- `sealed-secrets`: `Synced/Healthy`
- `imported-sealed-secrets`: `Synced/Healthy`
- `kyverno`: `Synced/Healthy`
- `kyverno-policies`: `Synced/Healthy`
- `grafana`: `Synced/Healthy`
- `alloy`: `Synced/Healthy`
- `tempo`: `Synced/Healthy`

Secrets observes:

- `observability/grafana-admin`
- `observability/deploy-lgtm-imported-secrets`
- `observability/deploy-lgtm-terraform-vars`

## Point d'attention en cours

Pendant le prune des anciens objets Mimir/Loki, le Kubernetes API server a commence a repondre avec des timeouts:

```text
Unable to connect to the server: net/http: TLS handshake timeout
Unable to connect to the server: context deadline exceeded
```

Le dernier diagnostic exploitable indiquait:

- Mimir avait bascule sur de nouveaux pods sans erreur Kafka.
- Les anciens StatefulSets Mimir `*-zone-*`, `mimir-kafka` et certains pods historiques etaient encore en suppression.
- Loki attendait la suppression des anciens StatefulSets de cache `loki-chunks-cache` et `loki-results-cache`.
- Les webhooks Mimir rollout etaient la cause du blocage Loki; ils ont ete retires du rendu Git au commit `4508b8c`.

## Reprise recommandee

Quand l'API server redevient joignable:

```powershell
kubectl -n argocd get applications deploy-lgtm-root sealed-secrets imported-sealed-secrets kyverno kyverno-policies grafana loki mimir alloy tempo -o wide
kubectl -n observability get pods
kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration | Select-String observability
```

Si les webhooks rollout existent encore, les supprimer:

```powershell
kubectl delete mutatingwebhookconfiguration prepare-downscale-observability --ignore-not-found
kubectl delete validatingwebhookconfiguration no-downscale-observability pod-eviction-observability zpdb-validation-observability --ignore-not-found
```

Puis relancer la reconciliation:

```powershell
kubectl -n argocd annotate application mimir loki argocd.argoproj.io/refresh=hard --overwrite
```

Critere de sortie restant:

- `mimir` et `loki` passent `Synced/Healthy`.
- Les pods `mimir-*` restants correspondent au profil non zone-aware.
- Les StatefulSets `loki-chunks-cache`, `loki-results-cache`, `mimir-kafka`, `mimir-ingester-zone-*` et `mimir-store-gateway-zone-*` ont disparu.
