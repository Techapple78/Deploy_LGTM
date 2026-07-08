# Rapport Phase 6 - Application du backlog de durcissement

Date: 2026-07-08

## Synthese

Le backlog Phase 6 est applique cote depot sous forme d'artefacts exploitables:

- politique audit Kubernetes pour K3S;
- exemple de configuration serveur K3S pour audit logging;
- exemple de decision encryption at rest;
- scripts de collecte de preuves RBAC/PSA/Kyverno/NetworkPolicies;
- runbook de mise en oeuvre et rollback;
- qualification initiale anonymisee des ecarts SEC-1.

Les modifications de flags K3S ne sont pas appliquees automatiquement depuis Git,
car elles impactent le control plane et necessitent une fenetre de maintenance.

## Etat d'avancement

| Lot | Sujet | Etat | Commentaire |
| --- | --- | --- | --- |
| P1.1 | API server K3S | Prepare | A qualifier sur fichier de configuration K3S serveur et arguments effectifs. |
| P1.2 | Admission controllers | Prepare | `NodeRestriction` et absence `AlwaysAdmit` a confirmer sur arguments effectifs. |
| P1.3 | PKI K3S / kubelet TLS | Prepare | Cartographie a faire sur les noeuds, sans ajouter de PKI externe par defaut. |
| P1.4 | Audit logging K3S | Pret a appliquer | Policy et exemple de config fournis. |
| P1.5 | Encryption at rest | Prepare | Procedure K3S native documentee, activation a faire apres sauvegarde. |
| P2.1 | Ciphers API/kubelet | A qualifier | Dependance a la compatibilite K3S et clients. |
| P2.2-P2.5 | RBAC | Collecte outillee | Script de collecte cree, revue manuelle requise. |
| P2.6 | PSA/Kyverno | Partiel | Enforce deja actif sur certaines policies; progression a faire par namespace. |
| P3 | Exploitation securite | Prepare | Smoke test audit et pistes Grafana/Loki documentes. |

## Artefacts crees

| Fichier | Role |
| --- | --- |
| `examples/k3s-hardening/audit-policy.yaml` | Politique audit Kubernetes orientee SEC-1. |
| `examples/k3s-hardening/server-config.audit-logging.example.yaml` | Arguments K3S API server pour activer les logs audit. |
| `examples/k3s-hardening/server-config.encryption.example.yaml` | Trace documentaire pour encryption at rest K3S. |
| `scripts/phase6/Collect-Phase6Evidence.ps1` | Export local des preuves cluster dans `local/phase6`. |
| `scripts/phase6/Test-K3sAuditLogging.ps1` | Generation d'un evenement audit de test. |
| `docs/runbooks/01-k3s-phase-6-hardening.md` | Runbook de mise en oeuvre, verification et rollback. |

## Collecte de preuves initiale

Le script `scripts/phase6/Collect-Phase6Evidence.ps1` a ete execute avec succes.
Les sorties brutes sont conservees hors Git dans `local/phase6/`.

Synthese anonymisee:

| Indicateur | Valeur |
| --- | ---: |
| Noeuds Kubernetes | 4 |
| Namespaces | 12 |
| ClusterRoles | 104 |
| ClusterRoleBindings | 78 |
| ClusterRoleBindings vers `cluster-admin` | 3 |
| NetworkPolicies | 35 |
| ClusterPolicies Kyverno | 5 |

Lecture:

- les `3` bindings vers `cluster-admin` doivent etre qualifies avant exposition controlee;
- les `35` NetworkPolicies montrent que l'isolation est deja engagee, mais pas encore prouvee exhaustive;
- les `5` ClusterPolicies Kyverno donnent une base d'admission, a faire progresser sans casser les charts tiers.

## Qualification initiale SEC-1

| Controle | Decision initiale | Action Phase 6 |
| --- | --- | --- |
| `1.2.1` anonymous auth | A investiguer | Lire les arguments effectifs K3S; corriger si l'anonymous auth est active. |
| `1.2.6` a `1.2.8` authorization mode | A investiguer | Confirmer `Node,RBAC`; corriger si `AlwaysAllow` est present. |
| `1.2.10`, `1.2.15` admission | A investiguer | Confirmer absence `AlwaysAdmit` et presence `NodeRestriction`. |
| `1.2.4`, `1.2.5`, `1.2.24`, `1.2.26`, `1.2.27`, `4.2.9` PKI/TLS | Faux positif probable ou config K3S specifique a confirmer | Cartographier `/var/lib/rancher/k3s/server/tls` et kubelet. |
| `1.2.18` a `1.2.21`, `3.2.1`, `3.2.2` audit logs | Corriger | Activer audit logging avec policy fournie. |
| `1.2.29`, `1.2.30` encryption at rest | Corriger apres sauvegarde | Utiliser `k3s secrets-encrypt`. |
| `5.1.x` RBAC | A investiguer | Collecter et revoir cluster-admin, secrets, wildcards, creation pods. |

## Commandes de validation

```powershell
.\scripts\phase6\Collect-Phase6Evidence.ps1
.\scripts\Test-Repository.ps1
```

Apres application des changements serveur K3S:

```powershell
.\scripts\phase6\Test-K3sAuditLogging.ps1 -Namespace default
kube-bench run --benchmark k3s-cis-1.7 --targets master,etcd,controlplane,node,policies
kube-bench run --benchmark k3s-cis-1.7 --targets node
```

## Go / No-Go maintenance

Go si:

- sauvegarde K3S disponible;
- acces console/hyperviseur disponible;
- rollback `config.yaml` pret;
- fenetre de maintenance validee;
- ArgoCD et LGTM sont stables avant changement.

No-Go si:

- pas de sauvegarde datastore;
- acces serveur incertain;
- cluster deja instable;
- aucune possibilite de rollback hors SSH.

## Prochaine etape

Appliquer `P1.4` audit logging sur le serveur K3S pendant une fenetre de maintenance,
tester la generation d'evenements, puis brancher la collecte Alloy/Loki si le
volume et le contenu des logs sont acceptables.
