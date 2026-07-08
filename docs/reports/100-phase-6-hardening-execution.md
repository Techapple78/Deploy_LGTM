# Rapport Phase 6 - Application du backlog de durcissement

Date: 2026-07-08

## Synthese

Le backlog Phase 6 est applique cote depot sous forme d'artefacts exploitables:

- politique audit Kubernetes pour K3S;
- exemple de configuration serveur K3S pour audit logging;
- exemple de decision encryption at rest;
- scripts de collecte de preuves RBAC/PSA/Kyverno/NetworkPolicies;
- runbook de mise en oeuvre et rollback;
- qualification initiale anonymisee des ecarts SEC-1;
- collecte Loki des audit logs K3S;
- dashboard Grafana securite Kubernetes;
- rapport P2/P3 RBAC, admission et exploitation securite.

Les modifications de flags K3S ne sont pas appliquees automatiquement depuis Git,
car elles impactent le control plane et necessitent une fenetre de maintenance.

## Etat d'avancement

| Lot | Sujet | Etat | Commentaire |
| --- | --- | --- | --- |
| P1.1 | API server K3S | Valide | Anonymous auth desactivee explicitement, authorization mode `Node,RBAC`. |
| P1.2 | Admission controllers | Valide | `NodeRestriction` active explicitement, `AlwaysAdmit` desactive explicitement. |
| P1.3 | PKI K3S / kubelet TLS | Partiel | Permissions TLS cartographiees; qualification kube-bench finale a rejouer. |
| P1.4 | Audit logging K3S | Valide | Logs audit produits, smoke test create/delete visible dans le fichier audit. |
| P1.5 | Encryption at rest | Valide | Activation effective apres `rotate-keys`; statut final `Enabled`, cle active `AES-CBC`. |
| P2.1 | Ciphers API/kubelet | A qualifier | Dependance a la compatibilite K3S et clients. |
| P2.2-P2.5 | RBAC | Qualifie | Bindings `cluster-admin`, acces secrets, wildcards et pods interactifs inventories. |
| P2.6 | PSA/Kyverno | Qualifie | Pas d'enforcement supplementaire tant que les violations restantes ne sont pas corrigees. |
| P3 | Exploitation securite | Partiel | Collecte audit Loki et dashboard Grafana ajoutes; alertes minimales definies. |

## Artefacts crees

| Fichier | Role |
| --- | --- |
| `examples/k3s-hardening/audit-policy.yaml` | Politique audit Kubernetes orientee SEC-1. |
| `examples/k3s-hardening/server-config.audit-logging.example.yaml` | Arguments K3S API server pour activer les logs audit. |
| `examples/k3s-hardening/server-config.encryption.example.yaml` | Trace documentaire pour encryption at rest K3S. |
| `scripts/phase6/Collect-Phase6Evidence.ps1` | Export local des preuves cluster dans `local/phase6`. |
| `scripts/phase6/Test-K3sAuditLogging.ps1` | Generation d'un evenement audit de test. |
| `docs/runbooks/01-k3s-phase-6-hardening.md` | Runbook de mise en oeuvre, verification et rollback. |
| `docs/reports/101-phase-6-p2-p3-security-ops.md` | Qualification P2/P3 RBAC, Kyverno, audit logs, dashboard et alerting. |

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

## Execution P1.4 - Audit logging

Etat: valide.

Actions realisees pendant la fenetre de maintenance:

- sauvegarde control plane effectuee;
- sauvegarde hyperviseur effectuee;
- copie de la policy audit sur le serveur K3S;
- ajout des arguments `kube-apiserver-arg` dans la configuration K3S;
- redemarrage controle du service `k3s`;
- verification des noeuds `Ready`;
- verification que le fichier audit est alimente;
- smoke test `ConfigMap` create/delete via `scripts/phase6/Test-K3sAuditLogging.ps1`.

Constats:

| Controle | Resultat |
| --- | --- |
| Service `k3s` apres redemarrage | `Running` |
| Noeuds Kubernetes | `Ready` |
| Pods en erreur bloquante | Aucun au controle post-redemarrage |
| Fichier audit | Present et alimente |
| Evenement smoke test | Create/delete visible dans l'audit log |

Decision:

- `P1.4` est considere valide cote serveur.
- La collecte Loki/Alloy des logs audit reste une etape P3 apres validation du volume et du contenu.

## Execution P1.5 - Encryption at rest

Etat: valide.

Actions realisees:

- verification initiale: encryption des secrets desactivee;
- execution de `k3s secrets-encrypt enable`;
- redemarrage controle du service `k3s`;
- verification des noeuds et des pods;
- smoke test de creation/suppression d'un Secret Kubernetes;
- diagnostic de l'etat `Disabled / start`;
- execution de `k3s secrets-encrypt rotate-keys`;
- redemarrage controle du service `k3s`;
- verification post-redemarrage;
- smoke test de creation/suppression d'un Secret Kubernetes.

Constats:

| Controle | Resultat |
| --- | --- |
| Cluster apres redemarrage | Disponible |
| Smoke test Secret | Create/get/delete OK |
| `rotate-keys` | OK, `keys rotated, reencryption finished` |
| Statut final `secrets-encrypt` | `Enabled`, `reencrypt_finished` |
| Cle active | `AES-CBC` |
| Nom de cle | `aescbckey-*` |

Erreur observee:

```text
secret-encrypt error ID 21926: missing annotation on node
secret-encrypt error ID 26147: missing annotation on node
```

Interpretation initiale:

- le cluster est reste fonctionnel;
- la commande d'activation n'a pas abouti a un etat chiffre effectif;
- l'etat `Disabled / start` indique que l'activation avait prepare le mecanisme,
  mais que la rotation/rechiffrement n'etait pas encore terminee;
- `k3s secrets-encrypt rotate-keys` a finalise l'activation et la reecriture;
- apres redemarrage, le cluster est reste sain.

Preuve locale:

- logs bruts recuperes hors Git dans `local/phase6/secret-encrypt-errors.log`;
- le fichier est ignore par Git et ne doit pas etre publie.

Validation finale:

| Controle | Resultat |
| --- | --- |
| Service `k3s` apres redemarrage | `active` |
| `readyz` API server | OK |
| Noeuds Kubernetes | `Ready` |
| Pods en erreur bloquante | Aucun au controle post-redemarrage |
| Smoke test Secret | Create/get/delete OK |

Decision:

- `P1.5` est considere valide cote control plane;
- conserver les sauvegardes control plane et hyperviseur comme point de rollback;
- ne pas publier les fichiers de credentiels K3S ni la cle AES-CBC;
- integrer la sauvegarde de `/var/lib/rancher/k3s/server/cred/` au processus
  d'exploitation securisee.

## Execution P1.1/P1.2 - API server et admission

Etat: valide operationnellement, a confirmer par le prochain kube-bench.

Actions realisees:

- sauvegarde du fichier `/etc/rancher/k3s/config.yaml`;
- ajout des arguments API server explicites;
- redemarrage controle du service `k3s`;
- verification des noeuds, pods, API `readyz`, audit logging et encryption at rest;
- smoke test audit `ConfigMap`;
- smoke test `Secret` create/get/delete.

Arguments ajoutes:

```yaml
kube-apiserver-arg:
  - "anonymous-auth=false"
  - "authorization-mode=Node,RBAC"
  - "enable-admission-plugins=NodeRestriction"
  - "disable-admission-plugins=AlwaysAdmit"
```

Constats:

| Controle | Resultat |
| --- | --- |
| Service `k3s` apres redemarrage | `active` |
| `readyz` API server | OK |
| Noeuds Kubernetes | `Ready` |
| Pods en erreur bloquante | Aucun au controle post-redemarrage |
| Encryption at rest | Toujours `Enabled` |
| Smoke test audit | OK |
| Smoke test Secret | OK |
| Test anonyme | Acces refuse a `system:anonymous` |

Decision:

- `P1.1` et `P1.2` sont consideres valides cote configuration runtime;
- le prochain `kube-bench` doit confirmer la baisse des `FAIL` sur `1.2.1`,
  `1.2.6`, `1.2.7`, `1.2.8`, `1.2.10` et `1.2.15`;
- le rollback est possible via la sauvegarde locale du `config.yaml` sur le
  serveur K3S.

## Qualification P1.3 - PKI K3S / kubelet TLS

Etat: partiel.

Constats:

| Controle | Resultat |
| --- | --- |
| Cles privees K3S sous `/var/lib/rancher/k3s/server/tls` | `600 root:root` |
| Certificats publics K3S | `644 root:root` |
| PKI externe additionnelle | Non ajoutee |
| Decision PKI | Conserver la PKI K3S native tant qu'aucun besoin multi-CA n'est demontre |

Interpretation:

- les permissions observees sur les cles privees sont conformes a l'objectif de
  restriction locale;
- plusieurs controles kube-bench TLS peuvent rester des faux positifs ou des
  specificites K3S, car K3S gere une partie des certificats et arguments via son
  superviseur interne;
- la qualification finale doit etre faite avec un nouveau rapport kube-bench
  apres P1.1/P1.2/P1.4/P1.5.

## Qualification initiale SEC-1

| Controle | Decision initiale | Action Phase 6 |
| --- | --- | --- |
| `1.2.1` anonymous auth | Corrige | `anonymous-auth=false` ajoute explicitement. |
| `1.2.6` a `1.2.8` authorization mode | Corrige | `authorization-mode=Node,RBAC` ajoute explicitement. |
| `1.2.10`, `1.2.15` admission | Corrige | `NodeRestriction` active, `AlwaysAdmit` desactive explicitement. |
| `1.2.4`, `1.2.5`, `1.2.24`, `1.2.26`, `1.2.27`, `4.2.9` PKI/TLS | Faux positif probable ou config K3S specifique a confirmer | Cartographier `/var/lib/rancher/k3s/server/tls` et kubelet. |
| `1.2.18` a `1.2.21`, `3.2.1`, `3.2.2` audit logs | Corrige | Audit logging actif et smoke test valide. |
| `1.2.29`, `1.2.30` encryption at rest | Corrige | `secrets-encrypt` actif, cle `AES-CBC`, smoke test Secret OK. |
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

Statut du re-benchmark:

- `kube-bench` n'est pas disponible dans le PATH Windows local;
- `kube-bench` n'a pas ete trouve sur le serveur K3S;
- le rapport post-durcissement reste donc a executer via installation controlee
  du binaire ou via un Job Kubernetes dedie.

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

## Execution P2/P3 - RBAC, admission et exploitation securite

Etat: partiel valide cote GitOps, a confirmer apres synchronisation ArgoCD.

Actions realisees:

- audit des `3` bindings `cluster-admin`;
- inventaire des roles avec acces potentiel aux secrets;
- inventaire des roles avec wildcards;
- inventaire des roles pouvant creer des pods ou des sous-ressources interactives;
- analyse des violations Kyverno;
- ajout de la collecte Alloy des audit logs K3S vers Loki;
- ajout du dashboard Grafana `Deploy_LGTM Kubernetes Security Audit`;
- definition des requetes d'alerting minimal.

Decisions:

- les bindings Traefik `cluster-admin` sont acceptes temporairement car generes
  par les `HelmChart` K3S embarques;
- aucun passage Kyverno supplementaire en `Enforce` n'est applique maintenant,
  car `require-run-as-non-root`, `require-seccomp-runtime-default` et
  `disallow-host-namespaces` ont encore des violations;
- l'alerting minimal doit etre active apres 24h d'observation Loki pour eviter
  les faux positifs bruyants.

Details:

- [101-phase-6-p2-p3-security-ops.md](101-phase-6-p2-p3-security-ops.md)

## Prochaine etape

Poursuivre la Phase 6:

1. qualifier `P1.1` et `P1.2` a partir des arguments effectifs K3S;
2. rejouer `kube-bench` des qu'un binaire ou job d'execution est disponible;
3. finaliser `P1.3` PKI/Kubelet TLS a partir du nouveau rapport;
4. synchroniser ArgoCD pour deployer Alloy/Grafana P3;
5. valider `{job="k3s-audit"}` dans Loki;
6. observer 24h avant activation des alertes;
7. sauvegarder explicitement les artefacts de chiffrement K3S hors Git;
8. ouvrir le chantier RBAC Traefik/ArgoCD separe.
