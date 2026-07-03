# Troubleshooting

## ArgoCD ne synchronise pas

```powershell
kubectl -n argocd get application deploy-lgtm-root -o yaml
kubectl -n argocd logs deploy/argocd-application-controller --tail=200
```

Verifiez le champ `repoURL` dans `gitops/argocd/app-of-apps/root-app.yaml`.

## SealedSecret non decrypte

```powershell
kubectl -n observability get sealedsecret
kubectl -n kube-system logs deploy/sealed-secrets-controller --tail=200
```

Causes frequentes: mauvais namespace, mauvais nom de secret, SealedSecret genere avec la cle d'un autre cluster.

## Grafana inaccessible

```powershell
kubectl -n observability get ingress
kubectl -n observability describe ingress grafana
kubectl -n observability get svc grafana
```

Verifiez DNS, TLS secret, classe Ingress Traefik et firewall.

## Loki/Mimir/Tempo instables

```powershell
kubectl -n observability get pvc
kubectl -n observability describe pod -l app.kubernetes.io/name=loki
kubectl -n observability describe pod -l app.kubernetes.io/name=mimir
kubectl -n observability describe pod -l app.kubernetes.io/name=tempo
```

Verifiez stockage, ressources CPU/memoire et retention.
