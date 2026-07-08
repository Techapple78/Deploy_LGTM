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
|   |-- 00-README.md
|   |-- 01-architecture.md
|   |-- 02-roadmap-pilotage.md
|   |-- 03-pods-inventory.md
|   |-- 04-network-flows.md
|   |-- 05-bootstrap.md
|   |-- 06-ci-workflows.md
|   |-- 07-security.md
|   |-- 08-security-hardening-plan.md
|   |-- 09-hardening-audit.md
|   |-- 10-operations.md
|   |-- 11-troubleshooting.md
|   |-- 12-validation-checklist.md
|   |-- adr/
|   |   |-- 001-mvp-replication-storage.md
|   |   |-- 002-kyverno-progressive-enforcement.md
|   |   |-- 003-sealed-secrets-supply-chain.md
|   |   `-- 004-netpol-default-deny-cidr.md
|   |-- integrations/
|   |   `-- 01-html-css-js-mysql-lgtm.md
|   `-- reports/
|       |-- 90-phase-2.md
|       |-- 91-phase-3.md
|       |-- 91-phase-3-validation.md
|       |-- 92-phase-4-first-gitops-sync.md
|       |-- 93-application-telemetry-integration-plan.md
|       |-- 94-phase-5-application-telemetry-deployment-plan.md
|       |-- 96-phase-5-test-results.md
|       |-- 97-kube-bench-benchmark-plan.md
|       `-- 98-kube-bench-results.md
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
|   |-- phase5-telemetry/
|   `-- security/
|       |-- kyverno/policies.yaml
|       `-- sealed-secrets/install.yaml
|-- scripts/
|   |-- bootstrap/README.md
|   |-- phase5/Test-Phase5Telemetry.ps1
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

Les commandes detaillees sont dans [docs/05-bootstrap.md](docs/05-bootstrap.md).

Les secrets importes restent locaux dans `secrets/tmp/` jusqu'a generation de SealedSecrets.

La phase 2 du MVP deployable controle est documentee dans [docs/reports/90-phase-2.md](docs/reports/90-phase-2.md).
La phase 3 de pre-deploiement controle est documentee dans [docs/reports/91-phase-3.md](docs/reports/91-phase-3.md).
L'inventaire des pods et les schemas de fonctionnement sont dans [docs/03-pods-inventory.md](docs/03-pods-inventory.md).
La roadmap et le pilotage projet sont dans [docs/02-roadmap-pilotage.md](docs/02-roadmap-pilotage.md).
Le plan de durcissement avant iteration 4 est dans [docs/08-security-hardening-plan.md](docs/08-security-hardening-plan.md).
Le fonctionnement des workflows CI est explique dans [docs/06-ci-workflows.md](docs/06-ci-workflows.md).
Le guide d'integration applicative LGTM est dans [docs/integrations/01-html-css-js-mysql-lgtm.md](docs/integrations/01-html-css-js-mysql-lgtm.md).

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

La checklist complete est dans [docs/12-validation-checklist.md](docs/12-validation-checklist.md).

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


