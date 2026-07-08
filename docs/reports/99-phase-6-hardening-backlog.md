# Backlog Phase 6 - Durcissement K3S apres kube-bench

Date: 2026-07-08

## Objectif

Transformer les resultats kube-bench SEC-1 en backlog de durcissement production.

Source principale:

- [98-kube-bench-results.md](98-kube-bench-results.md)

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

Priorite immediate:

1. rejouer `kube-bench` avec le profil `k3s-cis-1.7`;
2. finaliser la decision `P1.3` sur les controles PKI/kubelet TLS;
3. synchroniser ArgoCD pour deployer la collecte audit Loki et le dashboard Grafana;
4. valider les requetes `{job="k3s-audit"}` dans Loki;
5. sauvegarder et controler les artefacts de chiffrement K3S hors Git;
6. ouvrir un chantier RBAC dedie Traefik/ArgoCD;
7. corriger les violations Kyverno `runAsNonRoot` et `seccomp`.
