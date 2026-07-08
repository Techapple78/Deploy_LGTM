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

Etat: en cours.

Objectif:

- Deployer une application temoin maitrisee HTML/CSS/JavaScript/MySQL pour consommer la stack LGTM.
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
- Metriques API et MySQL visibles dans Mimir.
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

### Phase 6 - Durcissement production

Objectif:

- TLS automatise.
- NetworkPolicies.
- SSO Grafana avec Keycloak optionnel.
- Stockage objet pour Loki/Mimir/Tempo si volumetrie elevee.
- SBOM, signature images, policy admission avancee.

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

Phase 5:

1. Deployer une application temoin maitrisee HTML/CSS/JavaScript/MySQL dans un namespace dedie.
2. Instrumenter l'application et MySQL pour envoyer logs, metriques et traces vers Alloy.
3. Redeployer et tester le chemin OTLP de bout en bout vers Tempo.
4. Creer le dashboard Grafana applicatif et les alertes minimales.
5. Executer un plan de test complet: unitaire, global, stress, charge et regression.
6. Utiliser cette charge pour observer Loki, Mimir, Tempo, Alloy et Grafana sur 24h.
7. Ajuster ressources, retention et NetworkPolicies a partir des donnees observees.
8. Examiner les violations Kyverno/PSA avant tout passage supplementaire en `Enforce`.
9. Publier le rapport de test et mettre a jour la documentation.


