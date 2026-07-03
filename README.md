# Deploy_LGTM

Deploy_LGTM est un socle GitOps pour deployer une stack LGTM sur un cluster Kubernetes K3S existant, heberge sur des VM vSphere ESXi.

Le depot cible est `Techapple78/Deploy_LGTM`. Le cluster K3S est considere deja operationnel. Terraform ne cree pas le cluster; il est reserve a des elements vSphere utiles et optionnels. GitHub Actions valide le contenu du depot, puis ArgoCD applique les changements depuis Git.

## Synthese d'architecture

- Kubernetes: cluster K3S existant sur VM vSphere.
- GitOps: ArgoCD avec pattern app-of-apps.
- Observabilite: Grafana, Loki, Mimir, Tempo et Grafana Alloy.
- Exposition: Traefik expose Grafana en HTTPS.
- Securite: Kyverno pour les policies, Sealed Secrets pour stocker uniquement des secrets chiffres dans Git.
- CI/CD: GitHub Actions pour lint YAML, validation Kubernetes, rendu Helm et scans securite.
- Secrets: import local depuis `C:\XXX`, generation de Secrets temporaires, conversion en SealedSecrets avec `kubeseal`, commit uniquement des SealedSecrets.
- Identite: Keycloak est documente comme phase 2 pour le SSO Grafana.

## Arborescence

```text
.
|-- .github/workflows/
|   |-- lint.yml
|   |-- render.yml
|   `-- security.yml
|-- clusters/k3s/
|   |-- dev/kustomization.yaml
|   `-- prod/kustomization.yaml
|-- docs/
|   |-- architecture.md
|   |-- bootstrap.md
|   |-- operations.md
|   |-- security.md
|   `-- troubleshooting.md
|-- gitops/argocd/
|   |-- app-of-apps/root-app.yaml
|   `-- apps/*.yaml
|-- infra/terraform/vsphere/
|   |-- README.md
|   |-- main.tf
|   |-- outputs.tf
|   |-- providers.tf
|   `-- variables.tf
|-- platform/
|   |-- identity/keycloak-optional/README.md
|   |-- lgtm/{grafana,loki,mimir,tempo,alloy}/values.yaml
|   |-- networking/traefik/ingress-grafana.yaml
|   `-- security/
|       |-- kyverno/policies.yaml
|       `-- sealed-secrets/install.yaml
|-- scripts/
|   |-- bootstrap/README.md
|   `-- import-secrets/
|       |-- generate-sealed-secrets.ps1
|       `-- import-from-cxxx.ps1
|-- secrets/
|   |-- sealed/README.md
|   `-- templates/grafana-admin-secret.yaml
`-- examples/
    `-- cxxx-secrets.example.json
```

## Bootstrap rapide

```powershell
gh repo create Techapple78/Deploy_LGTM --private --source . --remote origin
git init
git add .
git commit -m "Initial LGTM GitOps scaffold"
git branch -M main
git push -u origin main

kubectl version --client
helm version
kubeseal --version
kubectl cluster-info

helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets
helm upgrade --install sealed-secrets-controller sealed-secrets/sealed-secrets --namespace kube-system --set fullnameOverride=sealed-secrets-controller --wait
.\scripts\import-secrets\import-from-cxxx.ps1 -SourcePath 'C:\XXX' -OutputPath '.\secrets\tmp\imported-secrets.json'
.\scripts\import-secrets\generate-sealed-secrets.ps1 -InputFile '.\secrets\tmp\imported-secrets.json' -OutputDir '.\secrets\sealed'

kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd --namespace argocd --wait
kubectl apply -f gitops/argocd/app-of-apps/root-app.yaml
```

Les commandes detaillees sont dans [docs/bootstrap.md](docs/bootstrap.md).

Pour importer les variables Terraform et secrets existants depuis `C:\Users\USER\Downloads\source-project`, voir [docs/source-deploy-crewai.md](docs/source-deploy-crewai.md). Les valeurs restent locales dans `secrets/tmp/` jusqu'a generation de SealedSecrets.

La phase 2 du MVP deployable controle est documentee dans [docs/phase-2.md](docs/phase-2.md).
La phase 3 de pre-deploiement controle est documentee dans [docs/phase-3.md](docs/phase-3.md).
L'inventaire des pods et les schemas de fonctionnement sont dans [docs/pods-inventory.md](docs/pods-inventory.md).
La roadmap et le pilotage projet sont dans [docs/roadmap-pilotage.md](docs/roadmap-pilotage.md).
Le plan de durcissement avant iteration 4 est dans [docs/security-hardening-plan.md](docs/security-hardening-plan.md).
Le fonctionnement des workflows CI est explique dans [docs/ci-workflows.md](docs/ci-workflows.md).

## Choix humains a confirmer

- Domaine public ou interne de Grafana, par defaut `grafana.example.local`.
- Mode TLS Traefik: secret TLS existant, cert-manager futur, ou certificat manuel.
- Classe de stockage K3S/vSphere a utiliser pour les volumes persistants.
- Sizing initial des composants LGTM selon retention, volume de logs, metriques et traces.
- Strategie de sauvegarde de la cle privee Sealed Secrets.
- Installation ArgoCD et premiere synchronisation GitOps.

## Validation post-deploiement

- ArgoCD root app `Synced` et `Healthy`.
- Namespaces `observability`, `security` et `networking` presents.
- Pods Grafana, Loki, Mimir, Tempo et Alloy en `Running`.
- Grafana accessible via Traefik en HTTPS.
- Datasources Grafana provisionnees vers Loki, Mimir et Tempo.
- Alloy envoie logs, metriques et traces vers les backends.
- Kyverno bloque les manifests non conformes.
- Aucun secret en clair dans `git status`, `git grep` ou les artefacts CI.

La checklist complete est dans [docs/validation-checklist.md](docs/validation-checklist.md).

## Methode iterative

Le projet suit une boucle courte: identification du besoin, modification du code, integration GitOps, tests unitaires de scripts, tests globaux de rendu, tests de regression CI, verification de telemetrie, review, puis planification du prochain increment.

## Risques, limites et arbitrages

- Sealed Secrets est simple et adapte au MVP, mais la perte de sa cle privee rend les SealedSecrets existants inutilisables.
- Les values Helm sont volontairement legeres; la production demandera sizing, retention, sauvegardes et HA.
- GitHub Actions ne deploie pas directement afin de garder ArgoCD comme source de verite.
- Terraform est minimal car le cluster existe deja.
- Keycloak est garde hors MVP pour limiter la complexite initiale.

## Roadmap MVP vers production

1. MVP: ArgoCD, Sealed Secrets, LGTM mononode/leger, Traefik HTTPS, policies Kyverno de base.
2. Durcissement: TLS automatise, ressources explicites, network policies, quotas, Pod Security Admission.
3. Resilience: HA Loki/Mimir/Tempo, stockage objet, backups, tests de restauration.
4. Securite: SSO Grafana avec Keycloak, rotation automatisee, signature d'images, SBOM.
5. Exploitation: SLO, alerting, dashboards capacite, runbooks, tests de regression GitOps.

