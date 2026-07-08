# Plan SEC-3 - Durcissement residuel avant production exposee

Date: 2026-07-08

## Objectif

SEC-3 transforme les ecarts residuels de SEC-2 en une iteration de
durcissement ciblee avant toute exposition production.

Point de depart:

- score de maturite: `72/100`;
- control plane kube-bench SEC-2: `60 PASS / 3 FAIL / 53 WARN / 15 INFO`;
- agents kube-bench SEC-2: `14 PASS / 2 FAIL / 2 WARN / 5 INFO` par agent;
- collecte audit K3S preparee dans Alloy;
- dashboard Grafana securite Kubernetes prepare.

Objectif de sortie:

- score cible: `80/100` minimum;
- `FAIL` control plane: `0` ou tous justifies comme specificites K3S;
- `FAIL` agents: `0` ou tous justifies comme specificites K3S;
- `WARN` control plane: moins de `40`, tous classes;
- alerting securite minimal valide apres observation;
- backlog RBAC/Kyverno/PSA priorise pour l'iteration production.

## Perimetre

Inclus:

- qualification des derniers `FAIL` kube-bench;
- durcissement kubelet compatible K3S;
- validation de la collecte audit Loki/Grafana;
- decision RBAC Traefik/ArgoCD;
- reduction progressive Kyverno/PSA;
- nouveau benchmark kube-bench SEC-3.

Exclus:

- remplacement complet de Traefik K3S;
- mise en place OIDC/SSO production;
- migration vers Vault ou External Secrets;
- enforcement image provenance global.

Ces sujets restent planifies mais ne doivent pas bloquer la cloture SEC-3 si les
risques residuels sont documentes.

## Pre-requis

- Sauvegarde control plane K3S recente.
- Sauvegarde hyperviseur ou snapshot valide.
- Acces SSH et console/hyperviseur operationnels.
- ArgoCD `Synced/Healthy` ou ecarts connus.
- LGTM stable avant modification kubelet.
- Logs audit K3S disponibles localement.
- Fenetre de maintenance validee pour tout changement `k3s` ou agent.

## Lot SEC3-P0 - Qualifier les FAIL restants

| ID | Controle | Action | Validation | Decision attendue |
| --- | --- | --- | --- | --- |
| SEC3-P0.1 | `1.2.28` API server `--etcd-cafile` | Verifier les chemins CA etcd K3S et arguments effectifs. | Preuve fichier/argument ou justification K3S. | Corrige, non applicable K3S ou faux positif documente. |
| SEC3-P0.2 | `4.2.4` kubelet read-only port | Verifier port kubelet effectif sur chaque noeud. | Aucune ecoute read-only non securisee. | Corrige ou faux positif documente. |
| SEC3-P0.3 | `4.2.9` kubelet TLS cert/key | Verifier certificats kubelet generes par K3S sur chaque noeud. | Certificat et cle presents, permissions correctes, usage compris. | Corrige ou specificite K3S documentee. |

Critere de sortie P0:

- aucun `FAIL` sans decision formelle;
- toutes les preuves brutes restent hors Git dans `local/phase6` ou equivalent;
- rapport SEC-3 mis a jour.

## Lot SEC3-P1 - Durcissement kubelet

| ID | Controle | Action | Risque | Garde-fou |
| --- | --- | --- | --- | --- |
| SEC3-P1.1 | `4.2.12` ciphers kubelet | Tester `tls-cipher-suites` sur un noeud agent. | Incompatibilite client ancien. | Rollback config agent et verification `kubectl logs/exec`. |
| SEC3-P1.2 | `4.2.13` pod PID limit | Definir puis tester `pod-max-pids`. | Limite trop basse pour LGTM. | Test Loki/Mimir/Tempo + Phase 5 telemetry. |
| SEC3-P1.3 | `1.2.22` request timeout | Decider `request-timeout` API server. | Effets sur operations longues. | Smoke ArgoCD sync + requetes Grafana. |

Critere de sortie P1:

- changements testes d'abord sur un agent quand applicable;
- pas de pod critique degrade;
- kube-bench ameliore ou exception documentee.

## Lot SEC3-P2 - Admission, PSA et Kyverno

| ID | Sujet | Action | Critere de sortie |
| --- | --- | --- | --- |
| SEC3-P2.1 | `EventRateLimit` | Concevoir configuration sans bloquer les evenements critiques. | Decision documentee ou test applique. |
| SEC3-P2.2 | `AlwaysPullImages` | Decider selon registry/cache/preload. | Active ou rejet justifie. |
| SEC3-P2.3 | `runAsNonRoot` | Corriger les workloads maitrisables. | Baisse des PolicyReports `fail`. |
| SEC3-P2.4 | `seccomp RuntimeDefault` | Corriger values Helm et workloads internes. | Baisse des PolicyReports `fail`. |
| SEC3-P2.5 | plugin NVIDIA | Formaliser exception host/privileged si necessaire. | Exception documentee. |

Critere de sortie P2:

- aucun passage Kyverno en `Enforce` sans observation;
- au moins une categorie de violations reduite;
- exceptions materiel/systeme explicites.

## Lot SEC3-P3 - RBAC et NetworkPolicies

| ID | Sujet | Action | Critere de sortie |
| --- | --- | --- | --- |
| SEC3-P3.1 | Traefik `cluster-admin` | Decider exception K3S ou migration GitOps future. | Decision signee dans docs. |
| SEC3-P3.2 | ArgoCD wildcards | Inventorier ressources reellement gerees. | Reduction proposee ou report justifie. |
| SEC3-P3.3 | acces secrets | Classer roles legitimes et suspects. | Liste justifiee. |
| SEC3-P3.4 | automount tokens | Desactiver sur workloads sans API Kubernetes. | Aucun workload projet inutilement tokenise. |
| SEC3-P3.5 | NetworkPolicies `argocd`/`kyverno` | Cartographier puis appliquer allowlist progressive. | Policies testees sans casser sync/admission. |

## Lot SEC3-P4 - Exploitation securite

| ID | Sujet | Action | Critere de sortie |
| --- | --- | --- | --- |
| SEC3-P4.1 | Collecte audit Loki | Synchroniser ArgoCD `alloy` et valider `{job="k3s-audit"}`. | Logs visibles dans Loki. |
| SEC3-P4.2 | Dashboard securite | Synchroniser Grafana et valider dashboard. | Dashboard accessible. |
| SEC3-P4.3 | Alerting minimal | Observer 24h puis activer seuils secrets/RBAC/exec/denied. | Alertes actives et non bruyantes. |
| SEC3-P4.4 | Runbook incident | Ajouter reaction aux alertes secrets/RBAC/exec. | Procedure exploitable. |

## Ordre d'execution recommande

1. Sauvegardes et verification cluster.
2. Qualification P0 sans changement si possible.
3. Sync ArgoCD Alloy/Grafana pour audit security.
4. Observation 24h des audit logs.
5. Changements kubelet P1 en fenetre controlee.
6. Remediation Kyverno/PSA P2 par namespace.
7. Decisions RBAC/NetworkPolicies P3.
8. Rejeu kube-bench SEC-3.
9. Mise a jour du score hardening.

## Go / No-Go

Go:

- sauvegarde valide;
- acces console disponible;
- LGTM stable;
- plan rollback documente;
- fenetre de maintenance confirmee.

No-Go:

- cluster deja instable;
- ArgoCD en drift non compris;
- aucun acces hors SSH;
- absence de sauvegarde recente;
- logs audit non consultables apres changement.

## Validation SEC-3

Commandes attendues:

```bash
kube-bench run --benchmark k3s-cis-1.7 --targets master,etcd,controlplane,node,policies
kube-bench run --benchmark k3s-cis-1.7 --targets node
```

Controles complementaires:

```powershell
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get --raw "/readyz?verbose"
.\scripts\Test-Repository.ps1
```

Rapport attendu:

- `docs/reports/104-kube-bench-after-sec-3.md`

## Definition of Done

- Les `FAIL` SEC-2 sont corriges ou justifies.
- Le score hardening est recalcule.
- Les alertes securite minimales sont activees ou leur activation est planifiee
  avec justification.
- Les exceptions K3S sont documentees.
- Le repo est valide et pousse.
