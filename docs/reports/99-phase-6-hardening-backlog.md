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
| P1.1 | Qualifier API server K3S | `1.2.1`, `1.2.6`, `1.2.7`, `1.2.8` | Anonymous auth, authorization mode et RBAC qualifies; vrais ecarts corriges. |
| P1.2 | Qualifier admission controllers | `1.2.10`, `1.2.15` | `AlwaysAdmit` et `NodeRestriction` qualifies; decision documentee. |
| P1.3 | Verifier certificats API server et kubelet | `1.2.4`, `1.2.5`, `1.2.24`, `1.2.26`, `1.2.27`, `4.2.9` | Cartographie PKI K3S documentee, permissions et arguments verifies. |
| P1.4 | Definir audit logging K3S | `1.2.18` a `1.2.21`, `3.2.1`, `3.2.2` | Audit policy creee, logs produits, rotation configuree, collecte Alloy/Loki planifiee ou active. |
| P1.5 | Evaluer encryption at rest | `1.2.29`, `1.2.30` | Decision sur encryption provider K3S et plan de rotation. |

Critere de sortie P1:

- aucun `FAIL` P1 sans decision;
- rapport de qualification K3S publie;
- runbook rollback disponible pour tout changement K3S server.

## Lot P2 - Crypto, RBAC et admission

| ID | Sujet | Source kube-bench | Sortie attendue |
| --- | --- | --- | --- |
| P2.1 | Durcir ciphers API server et kubelet | `1.2.31`, `4.2.12` | Liste de ciphers forte definie et testee, ou justification K3S documentee. |
| P2.2 | Auditer RBAC cluster-admin | `5.1.1` | Usages `cluster-admin` inventaries et reduits. |
| P2.3 | Auditer acces aux secrets | `5.1.2` | Roles ayant acces aux secrets justifies. |
| P2.4 | Reduire wildcards RBAC | `5.1.3` | Wildcards identifies, reduits ou justifies. |
| P2.5 | Controler creation de pods | `5.1.4` | Capacite `create pods` limitee aux acteurs necessaires. |
| P2.6 | Consolider PSA/Kyverno | `5.2.x`, `5.3.x`, `5.4.x` | Passage progressif de certaines policies de `Audit` vers `Enforce`. |

Critere de sortie P2:

- RBAC critique inventorie;
- exceptions documentees;
- au moins un lot Kyverno/PSA passe en enforcement sans regression.

## Lot P3 - Stabilisation exploitation

| ID | Sujet | Source kube-bench | Sortie attendue |
| --- | --- | --- | --- |
| P3.1 | Evaluer pod PID limit | `4.2.13` | Valeur cible definie ou justification de non-activation. |
| P3.2 | Formaliser dashboard audit Kubernetes | Audit logs | Dashboard Grafana et requetes Loki pour actions sensibles. |
| P3.3 | Alerting minimal securite | Audit logs, Kyverno | Alertes sur secrets, RBAC, pods privilegies, exec, admission. |
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

1. qualifier les `FAIL` API server;
2. qualifier le `FAIL` kubelet TLS `4.2.9`;
3. concevoir l'audit logging K3S sans exposer de secrets dans Loki.
