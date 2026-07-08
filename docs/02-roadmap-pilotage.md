# Roadmap et pilotage du projet

## Vision

Mettre en place une plateforme LGTM legere, GitOps, securisee et exploitable sur un cluster K3S existant, sans recreer l'infrastructure vSphere.

## Roadmap

### Phase 1 - Socle depot

Etat: termine.

Livrables:

- Arborescence GitOps.
- Values Helm LGTM.
- Workflows GitHub Actions.
- Documentation initiale.
- Scripts d'import de secrets.

### Phase 2 - MVP deployable controle

Etat: termine.

Livrables:

- Outillage local portable.
- Versions Helm pinnees.
- Sync waves ArgoCD.
- Terraform vSphere minimal valide.
- Documentation phase 2.

### Phase 3 - Pre-deploiement controle

Etat: termine.

Livrables:

- Sealed Secrets installe sur K3S.
- SealedSecrets generes depuis une source locale autorisee.
- Script de validation repository.
- Git local initialise et commits crees.
- Rapport de validation.

Depot GitHub:

- `https://github.com/Techapple78/Deploy_LGTM`
- Branche par defaut: `main`

### Iteration SEC-0 - Durcissement avant premiere synchronisation

Etat: termine.

Objectif:

- Poser les garde-fous de securite avant l'application de l'app-of-apps LGTM.
- Garder Kyverno en `Audit` pour observer avant enforcement.
- Ajouter NetworkPolicies versionnees.
- Ajouter SBOM et scan de dependances.
- Clarifier TLS, PSA, signature d'images et criteres Go/No-Go.

Critere de sortie:

- `scripts/Test-Repository.ps1` vert.
- CI security/render/sbom prete.
- RepoURL ArgoCD aligne sur `Techapple78/Deploy_LGTM`.
- Strategie TLS choisie avant exposition Grafana.

### Phase 4 - Publication et premiere synchronisation

Etat: termine.

Objectif:

- Verifier que `Techapple78/Deploy_LGTM` est accessible par ArgoCD.
- Connecter ArgoCD au depot.
- Appliquer l'app-of-apps.
- Verifier les applications ArgoCD `platform-namespaces`, `sealed-secrets`, `imported-sealed-secrets`, `kyverno`, `observability-network-policies`, `loki`, `mimir`, `tempo`, `grafana`, `alloy`, `traefik-grafana-ingress`.

Critere de sortie:

- ArgoCD root app `Synced/Healthy`.
- Grafana accessible via Traefik.
- Datasources Loki/Mimir/Tempo visibles dans Grafana.
- Correction post-incident Loki integree dans GitOps via `allow-loki-to-kubernetes-api`.

Rapport de suivi:

- `docs/reports/92-phase-4-first-gitops-sync.md`

### Phase 5 - Stabilisation production legere

Etat: termine.

Objectif:

- Deployer une application temoin maitrisee HTML/CSS/JavaScript pour consommer la stack LGTM.
- Generer une charge controlee de logs, metriques et traces via Alloy.
- Redeployer et valider le chemin OTLP en mode test approfondi.
- Ajuster ressources CPU/memoire.
- Confirmer StorageClass.
- Ajouter sauvegarde cle Sealed Secrets.
- Mettre Kyverno progressivement en `Enforce`.
- Ajouter dashboards et alerting.
- Lancer un plan de test complet: unitaire, global, stress, charge et regression.

Critere de sortie:

- Application temoin maitrisee accessible via Traefik.
- Logs applicatifs visibles dans Loki.
- Metriques applicatives visibles dans Mimir.
- Traces applicatives visibles dans Tempo.
- Chemin OTLP valide de bout en bout via Alloy vers Tempo.
- Dashboard Grafana applicatif cree.
- Runbooks valides.
- Restauration testee.
- Alertes essentielles actives.
- Rapport de plan de test complet publie: unitaire, global, stress, charge et regression.
- Documentation a jour.

Rapport de planification:

- une future iteration applicative maitrisee, sans dependance a une application exemple non maintenue
- [reports/95-phase-5-test-plan.md](reports/95-phase-5-test-plan.md)
- [reports/96-phase-5-test-results.md](reports/96-phase-5-test-results.md)

### Iteration SEC-1 - Benchmark kube-bench

Etat: executee.

Objectif:

- Executer un benchmark CIS Kubernetes/K3S avec `kube-bench`.
- Classer les resultats `PASS`, `WARN`, `FAIL`, `INFO`.
- Distinguer les ecarts reels des controles non applicables a K3S.
- Alimenter le backlog de durcissement Phase 6.

Rapport de planification:

- [reports/97-kube-bench-benchmark-plan.md](reports/97-kube-bench-benchmark-plan.md)
- [reports/98-kube-bench-results.md](reports/98-kube-bench-results.md)

### Phase 6 - Durcissement production

Etat: en cours.

Objectif:

- Traiter le backlog kube-bench SEC-1.
- Qualifier les ecarts K3S reels, non applicables ou faux positifs.
- Activer ou planifier l'audit logging K3S.
- Cartographier la PKI K3S avant toute decision de PKI externe.
- Durcir RBAC, PSA/Kyverno, NetworkPolicies et TLS.
- Rejouer kube-bench en sortie de phase.

Critere de sortie:

- Hardening maturity score cible: `75/100` minimum.
- `FAIL` kube-bench control plane: `0 a 5`, tous justifies.
- `FAIL` kube-bench agents: `0` ou justifies.
- `WARN` kube-bench total: moins de `35`, tous classes.
- Audit logging K3S defini et testable.
- PKI K3S documentee.
- Rapport post-durcissement publie.

Rapport de backlog:

- [reports/99-phase-6-hardening-backlog.md](reports/99-phase-6-hardening-backlog.md)
- [reports/100-phase-6-hardening-execution.md](reports/100-phase-6-hardening-execution.md)
- [runbooks/01-k3s-phase-6-hardening.md](runbooks/01-k3s-phase-6-hardening.md)

## Pilotage

## Rituels

| Rituel | Frequence | Objectif |
| --- | --- | --- |
| Revue backlog | Hebdomadaire | Prioriser risques, dette et besoins. |
| Revue GitOps | A chaque PR | Verifier rendu, securite, blast radius. |
| Validation cluster | Avant sync ArgoCD | Confirmer contexte, commandes, rollback. |
| Revue exploitation | Hebdomadaire au debut | Suivre capacite, erreurs et alertes. |

## Indicateurs

| Indicateur | Cible MVP |
| --- | --- |
| ArgoCD applications | `Synced/Healthy` |
| Sealed Secrets | Controller `Running`, cle sauvegardee |
| Grafana | HTTPS accessible |
| Loki | Logs interrogeables |
| Mimir | Remote write fonctionnel |
| Tempo | Traces OTLP visibles |
| Alloy | DaemonSet pret sur les noeuds cibles |
| CI | Workflows lint/render/security verts |
| Supply chain | Workflow SBOM vert et artefact SPDX disponible |

## Gouvernance des changements

Regle simple:

- Les changements Git sont libres apres validation CI.
- Les commandes `kubectl apply`, `helm upgrade`, `argocd sync` et `terraform apply` demandent une decision explicite.
- Les secrets ne transitent jamais en clair dans Git.
- Tout incident de secret impose rotation et regeneration des SealedSecrets.

## Matrice de risques

| Risque | Impact | Mitigation |
| --- | --- | --- |
| Perte cle Sealed Secrets | SealedSecrets inutilisables | Sauvegarde chiffree hors Git, procedure de regeneration. |
| Mauvais contexte kubectl | Deploiement sur mauvais cluster | Verification explicite du contexte avant commande mutable. |
| Drift ArgoCD | Etat cluster divergent | Sync policy, alerting, revue ArgoCD. |
| Storage local insuffisant | Perte ou saturation observabilite | Choisir StorageClass cible, retention, sauvegarde. |


## Prochaine iteration recommandee

Phase 6:

1. Appliquer le runbook Phase 6 pendant une fenetre de maintenance K3S.
2. Activer et verifier l'audit logging K3S.
3. Qualifier les `FAIL` API server, admission, PKI/TLS et encryption at rest.
4. Auditer RBAC avec les exports locaux `scripts/phase6`.
5. Rejouer kube-bench sur le meme profil `k3s-cis-1.7`.
6. Publier `docs/reports/100-kube-bench-after-hardening.md` ou renumeroter le rapport post-hardening si le rapport d'execution Phase 6 reste `100`.


