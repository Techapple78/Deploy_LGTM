# Rapport Phase 6 - P2/P3 RBAC, admission et exploitation securite

Date: 2026-07-08

## Synthese

Le lot P2/P3 avance en mode controle:

- RBAC audite et points sensibles identifies;
- Kyverno/PSA qualifies avant enforcement supplementaire;
- collecte des audit logs K3S preparee dans Alloy;
- dashboard Grafana securite Kubernetes ajoute;
- alerting minimal defini sous forme de requetes a activer.

## P2 - RBAC / Crypto / Admission

### Cluster-admin

| Binding | Sujet | Decision |
| --- | --- | --- |
| `cluster-admin` | `Group: system:masters` | A conserver: break-glass/admin Kubernetes natif. |
| `helm-kube-system-traefik` | `ServiceAccount: kube-system/helm-traefik` | Accepte temporairement: cree par le Helm Controller K3S pour le chart Traefik. |
| `helm-kube-system-traefik-crd` | `ServiceAccount: kube-system/helm-traefik-crd` | Accepte temporairement: cree par le Helm Controller K3S pour les CRD Traefik. |

Lecture:

- les deux bindings Traefik ne viennent pas du depot GitOps applicatif;
- ils sont portes par les objets `HelmChart` K3S `traefik` et `traefik-crd`;
- les supprimer sans remplacer le mecanisme K3S Traefik peut etre annule par le
  controller ou casser la reconciliation Traefik.

Action recommandee:

1. garder ces bindings tant que Traefik K3S embarque est utilise;
2. planifier une migration future vers Traefik gere entierement par GitOps si le
   moindre privilege RBAC devient prioritaire;
3. documenter ces deux bindings comme exception K3S temporaire.

### Roles ayant acces aux secrets

Synthese observee:

| Indicateur | Valeur |
| --- | ---: |
| ClusterRoles avec lecture potentielle de `secrets` | 18 |
| ClusterRoles avec wildcards | 11 |
| ClusterRoles pouvant creer `pods` ou sous-ressources interactives | 14 |

Roles sensibles a qualifier:

- `argocd-application-controller`;
- `argocd-server`;
- `alloy`;
- `loki-clusterrole`;
- `secrets-unsealer`;
- `traefik-kube-system`;
- roles systeme Kubernetes/K3S;
- roles `admin` et `edit`.

Decision:

- ne pas reduire brutalement les roles systeme;
- traiter en priorite les roles applicatifs et GitOps;
- conserver `secrets-unsealer` comme role necessaire au fonctionnement Sealed Secrets;
- reduire les wildcards ArgoCD seulement apres inventaire precis des applications
  gerees par ArgoCD.

### Wildcards RBAC

Les wildcards les plus importantes sont portees par:

- `cluster-admin`;
- `argocd-application-controller`;
- `argocd-server`;
- controllers Kubernetes/K3S systeme;
- `local-path-provisioner-role`;
- `system:kubelet-api-admin`.

Plan de reduction:

1. exclure temporairement les roles systeme Kubernetes/K3S;
2. analyser `argocd-application-controller` via les ressources reellement gerees;
3. separer les droits ArgoCD par perimetre si plusieurs projets apparaissent;
4. eviter de reduire `local-path-provisioner-role` sans test PVC complet;
5. documenter toute wildcard restante comme exception controlee.

### Pods, exec, attach, port-forward

Les droits sensibles sont a surveiller car ils permettent une interaction directe
avec les workloads:

- `create pods`;
- `create pods/exec`;
- `create pods/attach`;
- `create pods/portforward`.

Decision:

- surveiller ces actions dans les audit logs Kubernetes;
- alerter sur `pods/exec`, `pods/attach` et `pods/portforward`;
- reduire les droits `edit` et applicatifs apres inventaire des usages legitimes.

### Kyverno / PSA

Etat observe:

| Policy | Action | Decision |
| --- | --- | --- |
| `disallow-latest-tag` | `Enforce` | Conserver en enforcement. |
| `disallow-privileged-containers` | `Enforce` | Conserver en enforcement. |
| `disallow-host-namespaces` | `Audit` | Ne pas passer en enforcement: violation cote plugin NVIDIA. |
| `require-run-as-non-root` | `Audit` | Ne pas passer en enforcement: 64 violations. |
| `require-seccomp-runtime-default` | `Audit` | Ne pas passer en enforcement: 39 violations. |

Namespaces avec PSA `baseline` + `restricted` en audit/warn:

- `argocd`;
- `crewai`;
- `kyverno`;
- `observability`;
- `phase5-telemetry`.

Decision:

- ne pas ajouter d'enforcement global supplementaire tant que les violations
  Kyverno restent non corrigees;
- passer d'abord les workloads GitOps sous controle du projet en conformite
  `runAsNonRoot` et `seccompProfile: RuntimeDefault`;
- traiter `nvidia-device-plugin` comme exception technique potentielle.

## P3 - Exploitation securite

### Collecte Alloy/Loki des audit logs

Configuration ajoutee:

- montage read-only de `/var/log/kubernetes/audit`;
- source Alloy `loki.source.file "k3s_audit"`;
- labels Loki:
  - `job="k3s-audit"`;
  - `source_type="kubernetes-audit"`;
  - `node=<node>`.

Requete de validation:

```logql
{job="k3s-audit"}
```

Requetes utiles:

```logql
{job="k3s-audit"} | json | objectRef_resource="secrets"
{job="k3s-audit"} | json | objectRef_resource=~"roles|rolebindings|clusterroles|clusterrolebindings"
{job="k3s-audit"} | json | objectRef_subresource=~"exec|attach|portforward"
{job="k3s-audit"} | json | responseStatus_code=~"4..|5.."
```

### Dashboard Grafana

Dashboard ajoute:

- dossier: `Deploy_LGTM`;
- titre: `Deploy_LGTM Kubernetes Security Audit`;
- uid: `deploy-lgtm-k8s-security-audit`.

Panneaux:

- acces aux secrets;
- changements RBAC;
- acces interactifs aux pods;
- evenements API refuses ou en erreur;
- debit par verbe API;
- logs sensibles recents.

### Alerting minimal

Alertes a activer depuis Grafana apres validation de la collecte Loki:

| Alerte | Requete | Seuil initial |
| --- | --- | --- |
| Secret access | `sum(count_over_time({job="k3s-audit"} | json | objectRef_resource="secrets" [5m]))` | `> 0` hors fenetre de maintenance |
| RBAC change | `sum(count_over_time({job="k3s-audit"} | json | objectRef_resource=~"roles|rolebindings|clusterroles|clusterrolebindings" [5m]))` | `> 0` hors sync ArgoCD attendue |
| Pod exec/attach/portforward | `sum(count_over_time({job="k3s-audit"} | json | objectRef_subresource=~"exec|attach|portforward" [5m]))` | `> 0` |
| API denied/error | `sum(count_over_time({job="k3s-audit"} | json | responseStatus_code=~"4..|5.." [5m]))` | `> 10` a ajuster |
| Admission denied | `{job="k3s-audit"} | json | responseStatus_reason=~"Forbidden|Invalid"` | observation puis seuil |

Decision:

- ne pas activer un alerting bruyant avant 24h d'observation;
- commencer par des alertes Grafana en notification manuelle;
- brancher Alertmanager/Mimir ruler seulement apres stabilisation des seuils.

## Risques residuels

| Risque | Niveau | Traitement |
| --- | --- | --- |
| Traefik K3S conserve deux bindings `cluster-admin` | Moyen | Exception temporaire documentee. |
| ArgoCD conserve des wildcards | Moyen | A reduire apres inventaire des ressources gerees. |
| Kyverno `runAsNonRoot` et `seccomp` restent en Audit | Moyen | Remediation workload par workload. |
| Audit logs dans Loki peuvent contenir des identifiants d'objets | Moyen | Policy audit limitee, pas de `RequestResponse` sur secrets. |
| Alertes initiales bruyantes | Faible | Observation 24h avant notification forte. |

## Prochaine etape

1. Synchroniser ArgoCD pour deployer la collecte audit et le dashboard.
2. Valider `{job="k3s-audit"}` dans Loki.
3. Observer 24h les requetes d'alerting.
4. Ouvrir un chantier RBAC ArgoCD/Traefik separe.
5. Corriger les violations Kyverno `runAsNonRoot` et `seccomp` par namespace.
