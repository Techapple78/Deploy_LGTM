# Operations

## Routines

- Verifier ArgoCD: `kubectl -n argocd get applications`.
- Verifier observabilite: `kubectl -n observability get pods,svc,pvc`.
- Verifier Kyverno: `kubectl -n kyverno get pods`.
- Verifier Sealed Secrets: `kubectl -n kube-system logs deploy/sealed-secrets-controller --tail=100`.

## Sauvegardes

- Sauvegarder la cle privee Sealed Secrets avec chiffrement fort.
- Sauvegarder les PVC si Loki/Mimir/Tempo utilisent un stockage local.
- Exporter les dashboards Grafana importants vers Git.

## Mise a jour

1. Modifier les values Helm.
2. Executer les validations CI localement si possible.
3. Ouvrir une pull request.
4. Laisser GitHub Actions valider.
5. Merger.
6. Verifier la synchronisation ArgoCD.

## Telemetrie

Le socle doit exposer:

- Etat des pods et redemarrages.
- Volume de logs ingeres par Loki.
- Cardinalite et ingestion Mimir.
- Latence et erreurs Tempo.
- Etat des collecteurs Alloy.
