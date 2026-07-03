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

## Securite

- Kyverno est en mode `Audit` pour le MVP.
- Les violations Kyverno sont examinees avant passage en `Enforce`.
- Les manifests ne demandent pas de privilege inutile.

