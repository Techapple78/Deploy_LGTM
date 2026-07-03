# Phase 2 - MVP deployable controle

## Objectif

Transformer le scaffold en MVP pret a etre applique, tout en gardant une barriere claire avant toute modification du cluster K3S ou de vSphere.

## Avancement

- Outils portables installables dans `.tools/` via `scripts/bootstrap/Install-LocalTools.ps1`.
- `kubeseal`, `helm` et `terraform` utilisables sans installation systeme.
- Versions Helm pinnees dans ArgoCD et dans le workflow de rendu.
- Sync waves ArgoCD ajoutees pour rendre l'ordre de deploiement explicite.
- Module Terraform vSphere valide avec le provider `vmware/vsphere`.
- Import local source-project disponible dans `secrets/tmp/deploy-crewai-imported-secrets.json`.

## Ordre GitOps cible

| Wave | Application | Role |
| ---: | --- | --- |
| -30 | `platform-namespaces` | Cree les namespaces requis. |
| -20 | `sealed-secrets` | Installe le controller Sealed Secrets. |
| -20 | `kyverno` | Installe Kyverno. |
| -5 | `imported-sealed-secrets` | Applique les SealedSecrets importes. |
| 0 | `kyverno-policies` | Applique les policies en mode Audit. |
| 10 | `loki`, `mimir`, `tempo` | Deploie les backends LGTM. |
| 20 | `grafana` | Deploie l'interface et les datasources. |
| 30 | `alloy` | Deploie la collecte. |
| 40 | `traefik-grafana-ingress` | Expose Grafana. |

## Etat Sealed Secrets

`kubeseal` est disponible localement et le service `sealed-secrets-controller` a ete installe dans le cluster cible pendant la phase 3.

Etat initial observe avant phase 3:

```text
services "sealed-secrets-controller" not found
```

Cet etat est resolu. Les SealedSecrets importes depuis `source-project` ont ete generes dans `secrets/sealed/`.

## Commandes qui modifieraient le cluster

Ne pas executer sans validation humaine explicite:

```powershell
helm upgrade --install sealed-secrets-controller sealed-secrets/sealed-secrets `
  --namespace kube-system `
  --set fullnameOverride=sealed-secrets-controller `
  --wait

kubectl apply -f gitops/argocd/app-of-apps/root-app.yaml
kubectl apply -k clusters/k3s/dev
kubectl apply -k clusters/k3s/prod
```

## Generation apres installation du controller

```powershell
$env:PATH = (Resolve-Path '.\.tools').Path + ';' + $env:PATH

.\scripts\import-secrets\generate-sealed-secrets.ps1 `
  -InputFile '.\secrets\tmp\deploy-crewai-imported-secrets.json' `
  -OutputDir '.\secrets\sealed' `
  -Namespace observability
```

Fichiers attendus:

- `secrets/sealed/deploy-crewai-terraform-vars.sealedsecret.yaml`
- `secrets/sealed/deploy-crewai-imported-secrets.sealedsecret.yaml`

## Validations Phase 2

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap\Install-LocalTools.ps1
python -c "import yaml, pathlib; [list(yaml.safe_load_all(p.read_text(encoding='utf-8'))) for p in pathlib.Path('.').rglob('*.yaml') if 'secrets/tmp' not in str(p)]; print('YAML parse OK')"
.\.tools\terraform.exe -chdir=infra/terraform/vsphere validate
.\.tools\helm.exe template grafana grafana/grafana --version 10.5.15 --namespace observability -f platform/lgtm/grafana/values.yaml
```

## Decisions restantes apres phase 3

- Confirmer le domaine Grafana et le secret TLS Traefik.
- Confirmer la StorageClass cible.
- Decider si le `kubeconfig` importe doit rester local ou etre scelle pour un workload precis.
- Definir la sauvegarde chiffree de la cle privee Sealed Secrets.
