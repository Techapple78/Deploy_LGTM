# Plan benchmark kube-bench - Iteration SEC-1

Date: 2026-07-08

## Objectif

Planifier un benchmark de conformite Kubernetes/K3S avec `kube-bench` apres cloture de la Phase 5.

Le but est de mesurer l'ecart entre l'etat actuel du cluster et les recommandations CIS Kubernetes, puis d'alimenter le backlog de durcissement Phase 6.

Cette iteration est volontairement placee avant le durcissement production pour eviter de passer en `Enforce`, TLS generalise ou restrictions plus fortes sans mesure runtime du socle Kubernetes.

## Sources de reference

| Source | Usage |
| --- | --- |
| `aquasecurity/kube-bench` | Outil de benchmark CIS Kubernetes. |
| Documentation `kube-bench` | Modes d'execution, contraintes host PID, montages `/etc` et `/var`. |
| `k3s-cis-1.7` | Profil kube-bench dedie Rancher K3S. |
| K3S CIS Self-Assessment | Lecture complementaire pour interpreter les ecarts specifiques K3S. |

## Perimetre

| Cible | Incluse | Commentaire |
| --- | --- | --- |
| Noeud serveur K3S | Oui | Control plane, API server, etcd embarque ou datastore K3S selon installation. |
| Noeuds agents K3S | Oui | Kubelet, configuration node, permissions fichiers. |
| Workloads Deploy_LGTM | Indirect | Les workloads sont couverts par Kyverno, PSA, Trivy et NetworkPolicies. |
| vSphere / ESXi | Non | Hors perimetre kube-bench. A traiter avec un benchmark CIS VMware separe si necessaire. |

## Prerequis

- Acces administrateur au cluster K3S.
- Confirmation du contexte `kubectl`.
- Fenetre d'audit sans deploiement concurrent.
- Export des resultats hors Git si les rapports contiennent noms de noeuds, IP ou chemins locaux.

## Mode d'execution recommande

### Option A - Job Kubernetes par noeud

Utiliser l'image officielle `aquasec/kube-bench` en Job Kubernetes avec le profil `k3s-cis-1.7`.

Avantages:

- execution reproductible;
- resultats proches du cluster;
- pas d'installation durable sur les noeuds.

Limites:

- necessite `hostPID` et des montages host en lecture seule;
- certains controles fichier/systemd peuvent necessiter des chemins K3S specifiques;
- un Job unique ne couvre pas toujours tous les noeuds; planifier un passage par role ou par noeud;
- les resultats doivent etre relus manuellement pour K3S, car tous les controles CIS Kubernetes ne s'appliquent pas tels quels.

### Option B - Execution locale sur chaque noeud

Executer `kube-bench` directement sur chaque noeud via SSH.

Avantages:

- meilleure visibilite sur fichiers, services et permissions locales;
- plus adapte aux controles kubelet et node.

Limites:

- demande un acces OS;
- necessite une procedure de collecte et d'anonymisation des resultats.

## Commandes indicatives

Verification de version:

```powershell
kubectl version --short
kubectl get nodes -o wide
```

Execution en Job generique:

```powershell
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
kubectl delete job kube-bench
```

Execution ciblee K3S a prevoir dans le manifest du Job:

```text
kube-bench run --benchmark k3s-cis-1.7 --targets master,node,etcd,controlplane,policies
```

Execution locale indicative:

```powershell
kube-bench run --benchmark k3s-cis-1.7 --targets master,node,etcd,controlplane,policies
```

Les commandes exactes seront ajustees apres verification de la version K3S et du profil `kube-bench` disponible dans l'image retenue.

## Strategie d'execution

### Etape 1 - Preparation

1. Confirmer le contexte `kubectl`.
2. Identifier les roles des noeuds sans publier les noms/IP dans Git.
3. Verifier que la Phase 5 reste stable.
4. Creer un repertoire local ignore pour les sorties brutes: `reports-local/kube-bench/`.
5. Prevoir une version anonymisee pour Git.

### Etape 2 - Dry-run documentaire

1. Relire les droits demandes par le Job.
2. Confirmer les montages host requis.
3. Confirmer que le Job est supprime apres collecte.
4. Valider le Go/No-Go avant execution.

### Etape 3 - Execution

1. Executer kube-bench sur le ou les noeuds control plane.
2. Executer kube-bench sur les noeuds agents.
3. Collecter les logs bruts hors Git.
4. Supprimer les Jobs, pods et manifests temporaires.

### Etape 4 - Analyse

1. Compter les `PASS`, `WARN`, `FAIL`, `INFO`.
2. Classer les `FAIL` par impact.
3. Marquer les controles non applicables a K3S.
4. Croiser avec `09-hardening-audit.md`, Kyverno, PSA et NetworkPolicies.
5. Produire `98-kube-bench-results.md`.

## Donnees a ne pas publier

- noms reels des noeuds;
- adresses IP;
- chemins locaux sensibles;
- noms utilisateurs OS;
- tokens, certificats, kubeconfig;
- sortie brute complete non relue.

## Format d'anonymisation

| Donnee brute | Format Git |
| --- | --- |
| Noeud control plane reel | `k3s-server-1` |
| Noeud agent reel | `k3s-agent-1`, `k3s-agent-2` |
| IP interne | `<redacted-ip>` |
| Chemin local sensible | `<redacted-path>` |
| Nom utilisateur OS | `<redacted-user>` |

## Resultats attendus

Le rapport final devra separer:

- `PASS`: conforme;
- `WARN`: a analyser, parfois attendu sur K3S;
- `FAIL`: ecart a corriger ou a justifier;
- `INFO`: information sans action immediate.

## Grille de restitution

| Controle | Severite | Resultat | Applicabilite K3S | Decision |
| --- | --- | --- | --- | --- |
| API server | Haute/Moyenne | A mesurer | A confirmer | Corriger / accepter / non applicable |
| Kubelet | Haute/Moyenne | A mesurer | Oui | Corriger / accepter |
| Fichiers kubeconfig | Moyenne | A mesurer | Oui | Corriger permissions |
| Policies admission | Moyenne | A mesurer | Partiel | Completer Kyverno/PSA |
| NetworkPolicies | Moyenne | A mesurer | Oui | Consolider |

## Livrables

- `docs/reports/98-kube-bench-results.md`;
- matrice des ecarts CIS/K3S;
- backlog Phase 6 priorise;
- decisions d'acceptation de risque si un controle CIS n'est pas applicable a K3S.

## Critere de cloture SEC-1

- Benchmark execute sur le control plane et les agents cibles.
- Resultats bruts conserves hors Git.
- Rapport anonymise publie.
- `FAIL` et `WARN` classes par priorite.
- Plan Phase 6 mis a jour avec actions de durcissement.
- Aucun secret, IP ou chemin local sensible publie.

## Go / No-Go

Go si:

- Phase 5 est terminee;
- cluster stable;
- aucun incident de stockage ou CrashLoopBackOff LGTM actif;
- resultats anonymises avant publication Git.

No-Go si:

- cluster instable;
- contexte `kubectl` incertain;
- resultats contenant IP, noms sensibles ou chemins locaux non anonymises.

## Decision de planification

Decision: plan valide.

Prochaine action: executer l'iteration SEC-1 kube-bench apres confirmation explicite du contexte Kubernetes et de la fenetre d'audit.
