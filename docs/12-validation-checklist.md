# Checklist de validation post-deploiement

## Git et CI

- Le depot distant est `Techapple78/Deploy_LGTM`.
- Les repoURL ArgoCD pointent tous vers `https://github.com/Techapple78/Deploy_LGTM.git`.
- Les workflows `lint`, `security` et `render` passent.
- Aucun fichier ignore local n'apparait dans `git status --short`.
- Aucun `Secret` Kubernetes en clair n'est versionne.

## Cluster

- `kubectl get nodes -o wide` retourne tous les noeuds K3S en `Ready`.
- Une StorageClass par defaut ou explicitement choisie existe.
- Les namespaces `argocd`, `observability`, `kyverno` et `kube-system` sont sains.

## GitOps

- L'application `deploy-lgtm-root` est `Synced` et `Healthy`.
- Les applications Grafana, Loki, Mimir, Tempo, Alloy, Kyverno et Sealed Secrets sont visibles dans ArgoCD.
- Les synchronisations automatiques ne generent pas de drift permanent.

## Secrets

- `kubectl -n observability get secret grafana-admin` existe apres decryptage.
- Les fichiers dans `secrets/sealed/` sont de type `SealedSecret`.
- La cle privee Sealed Secrets est sauvegardee hors Git selon la procedure interne.

## LGTM

- Grafana est accessible via Traefik en HTTPS.
- Les datasources Loki, Mimir et Tempo sont configurees dans Grafana.
- Alloy tourne sur les noeuds attendus.
- Les logs arrivent dans Loki.
- Les metriques arrivent dans Mimir.
- Les traces OTLP arrivent dans Tempo.

## Phase 5 telemetry

- L'application ArgoCD `phase5-telemetry` est `Synced` et `Healthy`.
- Le namespace `phase5-telemetry` existe.
- Le pod `phase5-telemetry-app` est `Running`.
- L'Ingress `phase5-app.example.local` route vers le service `phase5-telemetry-app`.
- `GET /healthz` retourne `ok`.
- `GET /api/work` genere un log JSON et un `trace_id`.
- `GET /api/error` genere une erreur controlee visible dans Loki via `{pod=~"phase5-telemetry-app.*"} |= "trace_id"`.
- Mimir contient `up{app="phase5-telemetry-app"}`.
- Mimir contient les compteurs `phase5_http_requests_total` et `phase5_otlp_traces_sent_total`.
- Tempo permet de retrouver des traces du service `phase5-telemetry-app`.
- Grafana affiche le dashboard `Deploy_LGTM Phase 5 Telemetry Overview`.

## Securite

- Kyverno est en mode `Audit` pour le MVP.
- Les violations Kyverno sont examinees avant passage en `Enforce`.
- Les manifests ne demandent pas de privilege inutile.
- Les flux reseau et leur exhaustivite sont documentes dans [04-network-flows.md](04-network-flows.md).
- L'audit de durcissement CIS/K3s/Kubernetes est documente dans [09-hardening-audit.md](09-hardening-audit.md).

