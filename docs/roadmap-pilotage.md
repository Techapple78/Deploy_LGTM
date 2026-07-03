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

Etat: termine partiellement, bloque uniquement par GitHub distant.

Livrables:

- Sealed Secrets installe sur K3S.
- SealedSecrets generes depuis `source-project`.
- Script de validation repository.
- Git local initialise et commits crees.
- Rapport de validation.

Blocage:

- Le compte GitHub courant ne peut pas creer `TechApple/Deploy_LGTM`.

### Phase 4 - Publication et premiere synchronisation

Objectif:

- Creer/pousser `TechApple/Deploy_LGTM`.
- Connecter ArgoCD au depot.
- Appliquer l'app-of-apps.
- Verifier les applications ArgoCD `platform-namespaces`, `sealed-secrets`, `imported-sealed-secrets`, `kyverno`, `loki`, `mimir`, `tempo`, `grafana`, `alloy`, `traefik-grafana-ingress`.

Critere de sortie:

- ArgoCD root app `Synced/Healthy`.
- Grafana accessible via Traefik.
- Datasources Loki/Mimir/Tempo visibles dans Grafana.

### Phase 5 - Stabilisation production legere

Objectif:

- Ajuster ressources CPU/memoire.
- Confirmer StorageClass.
- Ajouter sauvegarde cle Sealed Secrets.
- Mettre Kyverno progressivement en `Enforce`.
- Ajouter dashboards et alerting.

Critere de sortie:

- Runbooks valides.
- Restauration testee.
- Alertes essentielles actives.

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
| ELK existant instable | Bruit operationnel | Suivi separe, migration progressive vers LGTM. |

## Prochaine iteration recommandee

Phase 4:

1. Corriger le droit GitHub ou creer manuellement `TechApple/Deploy_LGTM`.
2. Pousser `main`.
3. Verifier que les workflows GitHub Actions passent.
4. Appliquer l'app-of-apps ArgoCD.
5. Surveiller les pods LGTM et documenter l'inventaire post-sync.
