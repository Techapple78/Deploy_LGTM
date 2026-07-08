# Rapport kube-bench - Resultats SEC-1

Date: 2026-07-08

## Synthese

Benchmark execute avec `kube-bench` sur le cluster K3S apres cloture de la Phase 5.

Profil utilise:

- outil: `aquasec/kube-bench:v0.15.6`;
- benchmark: `k3s-cis-1.7`;
- targets control plane: `master,etcd,controlplane,node,policies`;
- targets agents: `node`.

Les sorties brutes sont conservees hors Git dans `local/kube-bench/`.

## Perimetre execute

| Cible anonymisee | Role | Targets kube-bench | Statut |
| --- | --- | --- | --- |
| `k3s-server-1` | Control plane | `master,etcd,controlplane,node,policies` | Execute |
| `k3s-agent-1` | Agent | `node` | Execute |
| `k3s-agent-2` | Agent | `node` | Execute |
| `k3s-agent-3` | Agent | `node` | Execute |

## Resultats globaux

| Perimetre | PASS | FAIL | WARN | INFO |
| --- | ---: | ---: | ---: | ---: |
| Control plane | 34 | 22 | 60 | 35 |
| Agents, total 3 noeuds | 45 | 3 | 6 | 24 |
| Total | 79 | 25 | 66 | 59 |

Lecture:

- `PASS`: controle conforme;
- `FAIL`: ecart automatise a investiguer ou corriger;
- `WARN`: controle manuel ou point a qualifier;
- `INFO`: information sans decision immediate.

## FAIL principaux

### Control plane

| Controle | Sujet | Priorite |
| --- | --- | --- |
| `1.2.1` | `--anonymous-auth=false` | Haute |
| `1.2.4` / `1.2.5` | Certificats client kubelet et CA kubelet | Haute |
| `1.2.6` / `1.2.7` / `1.2.8` | Modes d'autorisation API server: pas `AlwaysAllow`, inclure `Node` et `RBAC` | Haute |
| `1.2.10` / `1.2.15` | Admission controllers: `AlwaysAdmit`, `NodeRestriction` | Haute |
| `1.2.17`, `1.3.2`, `1.4.1` | Profiling a desactiver | Moyenne |
| `1.2.24`, `1.2.26`, `1.2.27`, `1.2.28` | Fichiers de certificats et CA API server / etcd | Haute |
| `1.2.31` | Ciphers cryptographiques forts API server | Haute |
| `1.3.3`, `1.3.4`, `1.3.5` | Controller manager et service accounts | Moyenne |
| `1.4.2` | Scheduler bind address loopback | Moyenne |
| `4.2.9` | Certificat et cle TLS kubelet | Haute |

### Agents

| Controle | Sujet | Priorite |
| --- | --- | --- |
| `4.2.9` | Certificat et cle TLS kubelet | Haute |

## WARN principaux

### Control plane

| Theme | Controles | Action |
| --- | --- | --- |
| Audit logs | `1.2.18` a `1.2.21`, `3.2.1`, `3.2.2` | Definir politique audit K3S avant production exposee. |
| Encryption at rest | `1.2.29`, `1.2.30` | Evaluer encryption provider K3S et rotation. |
| Etcd / datastore | `2.1` a `2.7` | Confirmer applicabilite selon datastore K3S reel. |
| Authentification utilisateurs | `3.1.1` a `3.1.3` | Revoir modes d'authentification admin. |
| RBAC | `5.1.1` a `5.1.6` | Auditer privileges, secrets, wildcard et creation de pods. |
| Admission / runtime | `5.2.x`, `5.3.x`, `5.4.x` | Croiser avec Kyverno, PSA et NetworkPolicies. |

### Agents

| Theme | Controles | Action |
| --- | --- | --- |
| Kubelet ciphers | `4.2.12` | Definir une liste de ciphers forte compatible K3S. |
| Pod PID limit | `4.2.13` | Evaluer `podPidsLimit` selon capacite et workloads. |

## Interpretation K3S

Certains controles CIS Kubernetes sont a qualifier avec prudence sur K3S:

- K3S encapsule plusieurs composants dans le binaire `k3s`;
- certains arguments ne sont pas exposes comme dans kubeadm;
- certains chemins de fichiers different des chemins Kubernetes standards;
- le datastore peut etre embarque ou externe selon l'installation.

Les `FAIL` ne doivent donc pas etre corriges mecaniquement. Chaque point doit etre classe:

- applicable et a corriger;
- applicable mais accepte temporairement;
- non applicable K3S;
- faux positif probable lie a la detection kube-bench.

## Backlog Phase 6 propose

| Priorite | Action | Justification |
| --- | --- | --- |
| P1 | Verifier la configuration API server K3S: anonymous auth, authorization mode, NodeRestriction | Plusieurs `FAIL` critiques. |
| P1 | Verifier kubelet TLS cert/key sur tous les noeuds | `4.2.9` en `FAIL` sur control plane et agents. |
| P1 | Definir audit logging K3S | Plusieurs `WARN` audit log. |
| P1 | Evaluer encryption at rest des secrets Kubernetes | `WARN` encryption provider. |
| P2 | Durcir ciphers API server et kubelet | `FAIL` / `WARN` crypto. |
| P2 | Auditer RBAC cluster-admin, secrets, wildcards, create pods | `WARN` politiques RBAC. |
| P2 | Consolider PSA/Kyverno vers enforcement progressif | Suite logique des controles policies. |
| P3 | Evaluer pod PID limit | Controle manuel agent. |

## Commandes executees

Execution par Jobs Kubernetes temporaires:

```powershell
kube-bench run --benchmark k3s-cis-1.7 --targets master,etcd,controlplane,node,policies
kube-bench run --benchmark k3s-cis-1.7 --targets node
```

Nettoyage:

```powershell
kubectl -n kube-system delete job -l app=kube-bench --ignore-not-found
```

## Controle post-execution

- Jobs temporaires kube-bench supprimes.
- Logs bruts conserves uniquement dans `local/kube-bench/`.
- Rapport Git anonymise.
- Aucune IP, aucun nom sensible et aucun secret publie.

## Conclusion

Iteration SEC-1 executee.

Le cluster est exploitable pour le lab controle, mais le benchmark confirme que le passage en production exposee doit attendre une phase de durcissement K3S dediee.

La Phase 6 doit commencer par qualifier les `FAIL` control plane, puis traiter les points kubelet, audit logging, encryption at rest, RBAC, PSA/Kyverno et NetworkPolicies.
