# Phase 3 - Pre-deploiement controle

## Etat realise

- Contexte Kubernetes verifie: `default`.
- Cluster K3S joignable avec 4 noeuds `Ready`.
- Sealed Secrets installe dans `kube-system`.
- Controller attendu disponible: `sealed-secrets-controller`.
- Secrets importes depuis `source-project` convertis en SealedSecrets.
- Validation locale centralisee dans `scripts/Test-Repository.ps1`.

## Changements deja appliques au cluster

Cette iteration a modifie le cluster uniquement pour installer le controller Sealed Secrets:

```powershell
helm upgrade --install sealed-secrets-controller sealed-secrets/sealed-secrets `
  --namespace kube-system `
  --set fullnameOverride=sealed-secrets-controller `
  --wait
```

Ressources observees:

- Deployment: `kube-system/sealed-secrets-controller`
- Service: `kube-system/sealed-secrets-controller`
- Service metrics: `kube-system/sealed-secrets-controller-metrics`
- Secret de cle privee: `kube-system/sealed-secrets-key...`

## SealedSecrets generes

Fichiers versionnables:

- `secrets/sealed/deploy-crewai-terraform-vars.sealedsecret.yaml`
- `secrets/sealed/deploy-crewai-imported-secrets.sealedsecret.yaml`

Ces fichiers sont chiffres pour le cluster courant. Si la cle privee Sealed Secrets du cluster change, ils devront etre regeneres depuis la source locale autorisee.

## Premier deploiement GitOps

Prerequis:

- ArgoCD installe dans le namespace `argocd`.
- Depot GitHub `TechApple/Deploy_LGTM` accessible par ArgoCD.
- Branche `main` poussee.

Commandes qui modifieront le cluster:

```powershell
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --wait
kubectl apply -f gitops/argocd/app-of-apps/root-app.yaml
```

## Rollback GitOps

Rollback applicatif:

1. Revenir au commit Git precedent.
2. Pousser `main`.
3. Laisser ArgoCD resynchroniser ou forcer la sync depuis l'UI/CLI.

Rollback d'urgence:

```powershell
kubectl -n argocd patch application deploy-lgtm-root --type merge `
  -p '{"spec":{"syncPolicy":null}}'
```

Ensuite, corriger Git puis reactiver la sync automatisee.

## Rotation Sealed Secrets

1. Mettre a jour la source locale dans `source-project` ou `C:\XXX`.
2. Relancer l'import local.
3. Relancer `generate-sealed-secrets.ps1`.
4. Commiter uniquement les nouveaux fichiers `SealedSecret`.
5. Synchroniser ArgoCD.

## Validation Phase 3

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Repository.ps1
kubectl -n kube-system get pods,svc,secret | Select-String sealed
python -c "import yaml, pathlib; [print(p.name, list(yaml.safe_load_all(p.read_text(encoding='utf-8')))[0].get('kind')) for p in pathlib.Path('secrets/sealed').glob('*.yaml')]"
```

## Decisions restantes

- Installer ArgoCD maintenant ou garder le depot pret.
- Creer/pousser le depot GitHub `TechApple/Deploy_LGTM`.
- Confirmer le domaine Grafana reel.
- Fournir ou generer le secret TLS `grafana-tls`.
- Choisir la StorageClass definitive pour les PVC LGTM.

## Documentation associee

- Inventaire des pods et schemas: `docs/pods-inventory.md`
- Roadmap et pilotage: `docs/roadmap-pilotage.md`
