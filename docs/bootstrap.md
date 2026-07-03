# Bootstrap

## Prerequis locaux

```powershell
git --version
gh --version
kubectl version --client
helm version
kubeseal --version
```

Installez les outils manquants avec votre gestionnaire prefere, par exemple `winget`.

```powershell
winget install Git.Git
winget install GitHub.cli
winget install Kubernetes.kubectl
winget install Helm.Helm
```

Pour `kubeseal`, telechargez `kubeseal.exe` depuis les releases officielles de Sealed Secrets, placez-le dans un dossier du `PATH`, puis verifiez avec `kubeseal --version`.

Alternative portable recommandee pour ce depot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap\Install-LocalTools.ps1
$env:PATH = (Resolve-Path '.\.tools').Path + ';' + $env:PATH
kubeseal --version
helm version
terraform version
```

## Creation du depot GitHub

```powershell
git init
gh repo create TechApple/Deploy_LGTM --private --source . --remote origin
git add .
git commit -m "Initial LGTM GitOps scaffold"
git branch -M main
git push -u origin main
```

## Verification K3S

```powershell
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass
```

## Installation de Sealed Secrets

```powershell
helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets
helm repo update
helm upgrade --install sealed-secrets-controller sealed-secrets/sealed-secrets `
  --namespace kube-system `
  --set fullnameOverride=sealed-secrets-controller `
  --wait
kubectl -n kube-system rollout status deployment/sealed-secrets-controller
kubeseal --fetch-cert --controller-name sealed-secrets-controller --controller-namespace kube-system > sealed-secrets-public-cert.pem
```

Le fichier `sealed-secrets-public-cert.pem` est public, mais il n'est pas necessaire de le commiter.

## Import des secrets depuis C:\XXX

```powershell
.\scripts\import-secrets\import-from-cxxx.ps1 `
  -SourcePath 'C:\XXX' `
  -OutputPath '.\secrets\tmp\imported-secrets.json'
```

Adaptez le mapping dans le fichier JSON temporaire si votre export local n'a pas les memes noms.

## Generation des SealedSecrets

```powershell
.\scripts\import-secrets\generate-sealed-secrets.ps1 `
  -InputFile '.\secrets\tmp\imported-secrets.json' `
  -OutputDir '.\secrets\sealed' `
  -Namespace observability
```

Verifiez que seuls des fichiers `kind: SealedSecret` sont ajoutes a Git.

```powershell
git status --short
git diff -- secrets/sealed
```

## Deploiement ArgoCD

```powershell
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --wait
kubectl apply -f gitops/argocd/app-of-apps/root-app.yaml
```

## Synchronisation LGTM

```powershell
kubectl -n argocd get applications
kubectl -n argocd get application deploy-lgtm-root -o yaml
kubectl -n observability get pods
```

## Verification fonctionnelle

```powershell
kubectl -n observability get svc
kubectl -n observability logs deploy/alloy --tail=100
kubectl -n observability port-forward svc/grafana 3000:80
```

Ouvrez `https://grafana.example.local` ou `http://localhost:3000` selon votre exposition.
