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
- `62a8fe6` - Separation du chemin local du compactor Mimir.
- `69c1361` - Documentation de reprise et activation du gRPC push ingester Mimir.
- `5554805` - Correction de l'egress Loki vers l'API Kubernetes apres incident post-redemarrage.
- `2fa9918` - Organisation de la documentation et numerotation de l'ordre de lecture.

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
- `k3s-agent-1` etait observe `NotReady`, avec plusieurs anciens pods Mimir encore attaches a ce noeud.
- Kyverno est passe temporairement en `CrashLoopBackOff`; ses webhooks fail-close pouvaient bloquer les operations Kubernetes tant que `kyverno-svc` n'avait pas d'endpoints.
- Mimir exige `ingester.push_grpc_method_enabled: true` lorsque `ingest_storage.enabled: false`; ce correctif est dans Git.

## Reprise realisee

Apres retour API et stabilisation du cluster:

- `deploy-lgtm-root` observe `Synced/Healthy`.
- `observability-network-policies` observe `Synced/Healthy`.
- `loki` observe `Synced/Healthy`.
- `loki-0` observe `2/2 Running`.
- Les conteneurs `loki` et `loki-sc-rules` sont revenus `ready=true` avec `restarts=0` apres correction.
- Le log `loki-sc-rules` confirme `Initial sync complete, sidecar is ready.`

Cause racine du dernier incident Loki:

- `observability-default-deny` isolait correctement le namespace.
- Le sidecar `loki-sc-rules` devait joindre l'API Kubernetes pour lire les `ConfigMap` et `Secret` labels `loki_rule`.
- L'egress vers `10.0.0.1:443` et l'endpoint API `192.0.2.10:6443` n'etait pas encore autorisee.
- La policy GitOps `allow-loki-to-kubernetes-api` a ete ajoutee et poussee.

## Reprise historique recommandee

Quand l'API server redevient joignable:

```powershell
kubectl -n argocd get applications deploy-lgtm-root sealed-secrets imported-sealed-secrets kyverno kyverno-policies grafana loki mimir alloy tempo -o wide
kubectl -n observability get pods
kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration | Select-String observability
kubectl -n kyverno get pods,svc,endpoints
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

Si Kyverno n'a pas d'endpoints et bloque les operations, supprimer temporairement ses webhook configurations puis relancer les pods Kyverno:

```powershell
kubectl delete validatingwebhookconfiguration kyverno-cel-exception-validating-webhook-cfg kyverno-cleanup-validating-webhook-cfg kyverno-exception-validating-webhook-cfg kyverno-global-context-validating-webhook-cfg kyverno-policy-validating-webhook-cfg kyverno-resource-validating-webhook-cfg kyverno-ttl-validating-webhook-cfg --ignore-not-found --wait=false
kubectl delete mutatingwebhookconfiguration kyverno-policy-mutating-webhook-cfg kyverno-resource-mutating-webhook-cfg kyverno-verify-mutating-webhook-cfg --ignore-not-found --wait=false
kubectl -n kyverno delete pod -l app.kubernetes.io/part-of=kyverno --wait=false
```

## Critere de sortie final

- `deploy-lgtm-root` est `Synced/Healthy`.
- `loki` est `Synced/Healthy` et `loki-0` est `2/2 Running`.
- Les NetworkPolicies necessaires au MVP sont versionnees.
- La documentation d'exploitation contient le diagnostic Loki post-redemarrage brutal.
- La Phase 4 est consideree terminee; la suite logique est la Phase 5 de stabilisation production legere.
