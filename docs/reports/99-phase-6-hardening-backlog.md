# Backlog Phase 6 - Durcissement K3S apres kube-bench

Date: 2026-07-08

## Objectif

Transformer les resultats kube-bench SEC-1 en backlog de durcissement production.

Source principale:

- [98-kube-bench-results.md](98-kube-bench-results.md)
- [102-kube-bench-after-phase-6.md](102-kube-bench-after-phase-6.md)
- [103-sec-3-hardening-plan.md](103-sec-3-hardening-plan.md)

Score de depart:

```text
Hardening maturity score: 58/100
Niveau: MVP securise avec reserves K3S / pre-production controlee
Statut: acceptable pour lab controle, insuffisant pour production exposee
```

## Sortie attendue Phase 6

Objectif de sortie:

```text
Hardening maturity score cible: 75/100 minimum
Niveau cible: pre-production durcie
Statut cible: acceptable pour exposition controlee apres validation TLS, audit logs, RBAC, PSA/Kyverno et sauvegardes
```

Objectif kube-bench a la sortie:

| Indicateur | Etat SEC-1 | Cible sortie Phase 6 |
| --- | ---: | ---: |
| `FAIL` control plane | 22 | 0 a 5, tous justifies |
| `FAIL` agents | 3 | 0 ou justifies |
| `WARN` total | 66 | moins de 35, tous classes |
| `PASS` total | 79 | en hausse ou stable |
| Ecarts non applicables K3S | Non classes | Classes et documentes |

La cible n'est pas un score CIS officiel. C'est un seuil de pilotage interne pour verifier que les ecarts critiques sont traites ou justifies avant production exposee.

## Evaluation SEC-2 apres Phase 6

Resultat control plane apres Phase 6:

| Iteration | PASS | FAIL | WARN | INFO | Lecture |
| --- | ---: | ---: | ---: | ---: | --- |
| SEC-1 initial | 79 | 25 | 66 | 59 | Baseline runtime apres Phase 5. |
| SEC-2 post Phase 6 | 60 | 3 | 53 | 15 | API server, audit logs et encryption at rest corriges. |

Resultat agents apres Phase 6:

| Perimetre | PASS | FAIL | WARN | INFO | Lecture |
| --- | ---: | ---: | ---: | ---: | --- |
| Chaque agent | 14 | 2 | 2 | 5 | Les ecarts restants sont homogenes sur les kubelets. |

Decision:

- la Phase 6 atteint l'objectif critique: les `FAIL` control plane passent de
  `22` a `3`;
- le score de maturite remonte a `72/100`;
- le cluster reste en pre-production durcie, pas encore production exposee;
- les ecarts restants doivent etre traites dans un backlog SEC-2 dedie avant
  tout passage production.

## Regles de traitement

Chaque controle kube-bench `FAIL` ou `WARN` doit recevoir une decision:

- `corriger`: ecart applicable et actionnable;
- `accepter temporairement`: ecart applicable mais reporte avec justification;
- `non applicable K3S`: controle non pertinent pour l'architecture K3S;
- `faux positif probable`: detection kube-bench incompatible avec le mode K3S, a confirmer;
- `a investiguer`: information insuffisante.

## Lot P1 - Socle K3S critique

| ID | Sujet | Source kube-bench | Sortie attendue |
| --- | --- | --- | --- |
| P1.1 | Qualifier API server K3S | `1.2.1`, `1.2.6`, `1.2.7`, `1.2.8` | Fait: `anonymous-auth=false` et `authorization-mode=Node,RBAC` appliques. |
| P1.2 | Qualifier admission controllers | `1.2.10`, `1.2.15` | Fait: `NodeRestriction` active, `AlwaysAdmit` desactive explicitement. |
| P1.3 | Verifier certificats API server et kubelet | `1.2.4`, `1.2.5`, `1.2.24`, `1.2.26`, `1.2.27`, `4.2.9` | Partiel: permissions TLS cartographiees; confirmation kube-bench a rejouer. |
| P1.4 | Definir audit logging K3S | `1.2.18` a `1.2.21`, `3.2.1`, `3.2.2` | Fait: audit policy appliquee, logs produits, smoke test valide. |
| P1.5 | Evaluer encryption at rest | `1.2.29`, `1.2.30` | Fait: `secrets-encrypt` actif, cle `AES-CBC`, rechiffrement termine. |

## Backlog SEC-2 - Ecarts residuels apres Phase 6

### Priorite P0 - Qualifier les derniers FAIL

| ID | Controle | Sujet | Decision actuelle | Action attendue | Critere de sortie |
| --- | --- | --- | --- | --- | --- |
| SEC2-P0.1 | `1.2.28` | API server `--etcd-cafile` | Specificite K3S probable | Verifier la CA etcd effective et documenter le mapping K3S. | Controle classe `corrige`, `non applicable K3S` ou `faux positif documente`. |
| SEC2-P0.2 | `4.2.4` | Kubelet read-only port | A verifier sur tous les noeuds | Confirmer la valeur effective `readOnlyPort: 0` ou appliquer `kubelet-arg`. | Plus de port read-only expose ou exception K3S prouvee. |
| SEC2-P0.3 | `4.2.9` | Kubelet TLS cert/key | Specificite K3S possible | Verifier presence et usage de `serving-kubelet.crt/key` sur chaque noeud. | Controle classe ou corrige par configuration explicite. |

### Priorite P1 - Durcissement kubelet compatible K3S

| ID | Controle | Sujet | Action attendue | Risque |
| --- | --- | --- | --- | --- |
| SEC2-P1.1 | `4.2.12` | Ciphers kubelet | Tester `tls-cipher-suites` via `kubelet-arg` sur un noeud, puis generaliser. | Incompatibilite client ancien ou agent. |
| SEC2-P1.2 | `4.2.13` | Pod PID limit | Definir une valeur `pod-max-pids` adaptee aux workloads LGTM. | Limite trop basse pouvant casser Mimir/Loki/Tempo. |
| SEC2-P1.3 | `1.2.22` | API request timeout | Evaluer `request-timeout=300s` ou justification du defaut. | Effets sur operations longues. |

### Priorite P2 - Admission et policies

| ID | Controle | Sujet | Action attendue | Critere de sortie |
| --- | --- | --- | --- | --- |
| SEC2-P2.1 | `1.2.9` | `EventRateLimit` | Concevoir une configuration d'admission control dediee. | Test sans perte d'evenements critiques. |
| SEC2-P2.2 | `1.2.11` | `AlwaysPullImages` | Decider selon registry/cache local; ne pas activer si usage offline/preload. | Decision documentee. |
| SEC2-P2.3 | `5.2.x`, `5.7.2`, `5.7.3` | PSA/Kyverno/seccomp/securityContext | Reduire violations `runAsNonRoot` et `seccomp` namespace par namespace. | Baisse mesurable des PolicyReports `fail`. |
| SEC2-P2.4 | `5.3.2` | NetworkPolicies par namespace | Etendre default deny/allowlist a `argocd` et `kyverno`. | Flux cartographies et policies testees. |

### Priorite P3 - RBAC et exploitation securite

| ID | Controle | Sujet | Action attendue | Critere de sortie |
| --- | --- | --- | --- | --- |
| SEC2-P3.1 | `5.1.1` | Bindings `cluster-admin` Traefik | Decider migration Traefik GitOps ou exception K3S long terme. | Binding reduit ou exception signee. |
| SEC2-P3.2 | `5.1.2`, `5.1.3`, `5.1.4` | Secrets, wildcards, create pods | Reduire roles ArgoCD/operateurs apres inventaire d'usage. | Liste de roles reduits ou justifies. |
| SEC2-P3.3 | `5.1.6` | Automount service account token | Desactiver par defaut sur workloads qui n'utilisent pas l'API Kubernetes. | Aucun pod applicatif inutilement tokenise. |
| SEC2-P3.4 | Audit logs | Alerting Grafana | Observer 24h `{job="k3s-audit"}`, puis activer alertes secrets/RBAC/exec. | Alertes actives avec seuils non bruyants. |

### Priorite P4 - Identite et production exposee

| ID | Controle | Sujet | Action attendue | Critere de sortie |
| --- | --- | --- | --- | --- |
| SEC2-P4.1 | `3.1.1` a `3.1.3` | Authentification utilisateurs | Planifier OIDC/SSO pour administrateurs humains. | Acces humain decouple des certificats/token historiques. |
| SEC2-P4.2 | `5.5.1` | Image provenance | Definir signature images internes et verification admission. | Politique image signee en Audit puis Enforce. |
| SEC2-P4.3 | `5.4.2` | Secret storage externe | Evaluer Vault/SOPS/External Secrets selon cible production. | Decision ADR. |

Critere de sortie P1:

- aucun `FAIL` P1 sans decision;
- rapport de qualification K3S publie;
- runbook rollback disponible pour tout changement K3S server.

## Lot P2 - Crypto, RBAC et admission

| ID | Sujet | Source kube-bench | Sortie attendue |
| --- | --- | --- | --- |
| P2.1 | Durcir ciphers API server et kubelet | `1.2.31`, `4.2.12` | Liste de ciphers forte definie et testee, ou justification K3S documentee. |
| P2.2 | Auditer RBAC cluster-admin | `5.1.1` | Fait: 3 bindings inventories, exceptions Traefik K3S documentees. |
| P2.3 | Auditer acces aux secrets | `5.1.2` | Fait: roles sensibles inventories, reduction reportee apres analyse applicative. |
| P2.4 | Reduire wildcards RBAC | `5.1.3` | Partiel: wildcards identifiees, reduction ArgoCD/Traefik a traiter separement. |
| P2.5 | Controler creation de pods | `5.1.4` | Fait: roles sensibles identifies, surveillance audit ajoutee. |
| P2.6 | Consolider PSA/Kyverno | `5.2.x`, `5.3.x`, `5.4.x` | Partiel: pas d'enforcement supplementaire avant remediation des violations. |

Critere de sortie P2:

- RBAC critique inventorie;
- exceptions documentees;
- au moins un lot Kyverno/PSA passe en enforcement sans regression.

## Lot P3 - Stabilisation exploitation

| ID | Sujet | Source kube-bench | Sortie attendue |
| --- | --- | --- | --- |
| P3.1 | Evaluer pod PID limit | `4.2.13` | Valeur cible definie ou justification de non-activation. |
| P3.2 | Formaliser dashboard audit Kubernetes | Audit logs | Fait: dashboard `Deploy_LGTM Kubernetes Security Audit` ajoute. |
| P3.3 | Alerting minimal securite | Audit logs, Kyverno | Partiel: requetes d'alerting definies, activation apres observation 24h. |
| P3.4 | Rejouer kube-bench | Tous | Nouveau rapport `100-kube-bench-after-hardening.md`. |

Critere de sortie P3:

- exploitation securite visible dans Grafana;
- alertes essentielles definies;
- benchmark post-durcissement execute et compare.

## Kube-bench attendu en sortie

Le benchmark de sortie doit etre execute avec le meme profil:

```powershell
kube-bench run --benchmark k3s-cis-1.7 --targets master,etcd,controlplane,node,policies
kube-bench run --benchmark k3s-cis-1.7 --targets node
```

Rapport attendu:

- `docs/reports/100-kube-bench-after-hardening.md`

Tableau attendu:

| Perimetre | PASS | FAIL | WARN | INFO | Decision |
| --- | ---: | ---: | ---: | ---: | --- |
| Control plane | A mesurer | 0 a 5 | moins de 30 | A mesurer | Tous les ecarts justifies |
| Agents | A mesurer | 0 | moins de 5 | A mesurer | Tous les ecarts justifies |

## Definition of Done Phase 6

- Tous les `FAIL` kube-bench sont corriges, justifies ou marques non applicables K3S.
- Audit logging K3S est defini et testable.
- PKI K3S existante est cartographiee avant toute decision de PKI externe.
- RBAC sensible est inventorie.
- PSA/Kyverno ont un plan d'enforcement progressif.
- NetworkPolicies restent coherentes apres durcissement.
- `scripts/Test-Repository.ps1` reste vert.
- Rapport post-durcissement publie.

## Decision

Phase 6 peut demarrer par le lot P1.

Priorite immediate SEC-2:

1. qualifier les trois `FAIL` restants: `1.2.28`, `4.2.4`, `4.2.9`;
2. verifier explicitement les kubelets sur chaque noeud avant ajout de
   `kubelet-arg`;
3. synchroniser ArgoCD pour deployer la collecte audit Loki et le dashboard Grafana;
4. valider les requetes `{job="k3s-audit"}` dans Loki;
5. sauvegarder et controler les artefacts de chiffrement K3S hors Git;
6. ouvrir un chantier RBAC dedie Traefik/ArgoCD;
7. corriger les violations Kyverno `runAsNonRoot` et `seccomp`;
8. rejouer kube-bench en SEC-3 apres correction P0/P1.

## Planification SEC-3

Le backlog SEC-2 est transforme en iteration SEC-3 dans
[103-sec-3-hardening-plan.md](103-sec-3-hardening-plan.md).

Objectif SEC-3:

- qualifier ou corriger les `3` FAIL control plane restants;
- qualifier ou corriger les `2` FAIL kubelet recurrents sur les agents;
- valider la collecte audit Loki/Grafana;
- reduire au moins une famille de violations Kyverno/PSA;
- statuer sur les exceptions RBAC Traefik/ArgoCD;
- rejouer kube-bench et publier `104-kube-bench-after-sec-3.md`.
