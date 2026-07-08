# Rapport kube-bench apres Phase 6

Date: 2026-07-08

## Objectif

Mesurer l'effet du durcissement Phase 6 apres:

- activation des audit logs K3S;
- activation de l'encryption at rest des secrets;
- durcissement explicite de l'API server;
- qualification RBAC/Kyverno/PSA;
- preparation de l'exploitation securite Loki/Grafana.

## Methode

`kube-bench` n'etant pas installe localement, le binaire officiel a ete telecharge
temporairement sur les noeuds dans `/tmp/kube-bench-phase6`.

Version executee:

```text
kube-bench 0.9.0
```

Benchmark:

```text
k3s-cis-1.7
```

Sources:

- kube-bench officiel: https://github.com/aquasecurity/kube-bench
- documentation d'execution: https://aquasecurity.github.io/kube-bench/v0.9.0/running/

Les sorties brutes sont conservees hors Git dans `local/phase6/`.

## Resultats

### Control plane

Commande executee sur le noeud control plane:

```bash
sudo ./kube-bench run \
  --config-dir /tmp/kube-bench-phase6/cfg \
  --config /tmp/kube-bench-phase6/cfg/config.yaml \
  --benchmark k3s-cis-1.7 \
  --targets=master,etcd,controlplane,node,policies
```

Synthese:

| Perimetre | PASS | FAIL | WARN | INFO |
| --- | ---: | ---: | ---: | ---: |
| master | 45 | 1 | 5 | 10 |
| etcd | 0 | 0 | 7 | 0 |
| controlplane | 1 | 0 | 4 | 0 |
| node control plane | 14 | 2 | 2 | 5 |
| policies | 0 | 0 | 35 | 0 |
| total control plane | 60 | 3 | 53 | 15 |

### Agents

Commande executee sur chaque noeud agent:

```bash
sudo ./kube-bench run \
  --config-dir /tmp/kube-bench-phase6/cfg \
  --config /tmp/kube-bench-phase6/cfg/config.yaml \
  --benchmark k3s-cis-1.7 \
  --targets=node
```

Synthese:

| Perimetre | PASS | FAIL | WARN | INFO |
| --- | ---: | ---: | ---: | ---: |
| agent 1 | 14 | 2 | 2 | 5 |
| agent 2 | 14 | 2 | 2 | 5 |
| agent workload additionnel | 14 | 2 | 2 | 5 |

## Evolution depuis SEC-1

SEC-1 initial:

```text
PASS 79 / FAIL 25 / WARN 66 / INFO 59
```

Apres Phase 6, le control plane passe a:

```text
PASS 60 / FAIL 3 / WARN 53 / INFO 15
```

Lecture:

- les `FAIL` critiques API server sont corriges;
- audit logging est maintenant reconnu en `PASS`;
- encryption at rest est maintenant reconnue en `PASS`;
- les `FAIL` restants sont concentres sur `etcd-cafile` et kubelet;
- les `WARN` restants correspondent surtout aux controles manuels CIS et au
  backlog RBAC/PSA/Kyverno deja documente.

## FAIL restants

| Controle | Sujet | Lecture Phase 6 | Decision |
| --- | --- | --- | --- |
| `1.2.28` | `--etcd-cafile` API server | K3S gere automatiquement la CA etcd. A verifier comme specificite K3S avant correction. | A qualifier. |
| `4.2.4` | read-only port kubelet | K3S annonce le defaut attendu a `0`, mais kube-bench continue de signaler un FAIL. | A verifier sur chaque noeud. |
| `4.2.9` | kubelet TLS cert/key | K3S gere automatiquement les certificats kubelet. Potentiel faux positif ou controle a expliciter. | A qualifier. |

Les agents presentent les memes deux `FAIL` kubelet:

- `4.2.4`;
- `4.2.9`.

## WARN principaux

| Groupe | Sujet | Decision |
| --- | --- | --- |
| API server | `EventRateLimit`, `AlwaysPullImages`, `request-timeout` | A etudier avant activation, car impact possible sur workloads et registry locale. |
| etcd | checks manifest `/etc/kubernetes/manifests/etcd.yaml` | Probable specificite K3S: pas de static pod manifest etcd. |
| control plane | authentification utilisateurs, audit policy coverage | OIDC/SSO et revue audit policy a planifier. |
| kubelet | ciphers, pod PID limit | A durcir par `kubelet-arg` apres fenetre de maintenance. |
| policies | RBAC, PSA, NetworkPolicies, secrets, seccomp | Backlog P2/P3 documente dans `101-phase-6-p2-p3-security-ops.md`. |

## Decision

La Phase 6 a fortement reduit les ecarts runtime:

- `anonymous-auth=false`: valide;
- `authorization-mode=Node,RBAC`: valide;
- `NodeRestriction`: valide;
- audit logs: valide;
- encryption at rest: valide;
- RBAC/PSA/Kyverno: qualifie, reductions restantes a traiter par lots.

Le cluster reste en pre-production durcie, pas encore production exposee.

## Actions suivantes

1. Qualifier `1.2.28`, `4.2.4` et `4.2.9` comme vrais ecarts ou specificites K3S.
2. Ajouter `pod-max-pids` et ciphers kubelet en fenetre controlee si compatible.
3. Reduire les bindings et wildcards ArgoCD/Traefik apres inventaire.
4. Corriger les violations Kyverno `runAsNonRoot` et `seccomp`.
5. Observer 24h la collecte `{job="k3s-audit"}` apres sync ArgoCD.
