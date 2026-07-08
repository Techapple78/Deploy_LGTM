# Runbook Phase 6 - Durcissement K3S

## Objectif

Appliquer le backlog Phase 6 sans casser le control plane K3S. Les changements
serveur sont traites comme des operations de maintenance, pas comme un simple
commit GitOps.

## Ordre recommande

1. Sauvegarder le datastore K3S et `/etc/rancher/k3s/`.
2. Collecter les preuves avec `scripts/phase6/Collect-Phase6Evidence.ps1`.
3. Qualifier les ecarts kube-bench P1.
4. Activer l'audit logging K3S sur un serveur de test ou pendant une fenetre de maintenance.
5. Verifier que les logs audit sont produits localement.
6. Brancher la collecte Alloy/Loki apres validation du volume et du contenu.
7. Evaluer `secrets-encryption` avec test de restauration.
8. Rejouer kube-bench avec le profil `k3s-cis-1.7`.

## Audit logging K3S

Fichiers fournis:

- `examples/k3s-hardening/audit-policy.yaml`;
- `examples/k3s-hardening/server-config.audit-logging.example.yaml`.

Procedure:

```powershell
scp examples/k3s-hardening/audit-policy.yaml <admin>@<k3s-server>:/tmp/audit-policy.yaml
ssh <admin>@<k3s-server>
sudo mkdir -p /etc/rancher/k3s /var/log/kubernetes/audit
sudo cp /tmp/audit-policy.yaml /etc/rancher/k3s/audit-policy.yaml
sudo cp /etc/rancher/k3s/config.yaml /etc/rancher/k3s/config.yaml.$(date +%Y%m%d%H%M%S).bak
sudo vi /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s
sudo systemctl status k3s --no-pager
```

Ajouter les arguments `kube-apiserver-arg` du fichier exemple dans la configuration
serveur existante. Ne pas remplacer aveuglement un fichier `config.yaml` deja
present.

Verification:

```powershell
kubectl get nodes
.\scripts\phase6\Test-K3sAuditLogging.ps1 -Namespace default
```

Puis sur le serveur:

```bash
sudo tail -n 50 /var/log/kubernetes/audit/audit.log
```

## Regles de contenu audit

- Utiliser `Metadata` par defaut pour limiter les donnees sensibles.
- Utiliser `Request` seulement pour les operations de changement.
- Ne pas utiliser `RequestResponse` sur les secrets.
- Surveiller en priorite RBAC, secrets, `pods/exec`, webhooks, Kyverno,
  NetworkPolicies et applications ArgoCD.

## API server et admission

Avant modification:

- sauvegarder `/etc/rancher/k3s/config.yaml`;
- verifier que le cluster est stable;
- conserver un acces console ou hyperviseur.

Arguments recommandes dans `kube-apiserver-arg`:

```yaml
kube-apiserver-arg:
  - "anonymous-auth=false"
  - "authorization-mode=Node,RBAC"
  - "enable-admission-plugins=NodeRestriction"
  - "disable-admission-plugins=AlwaysAdmit"
```

Verification apres redemarrage:

```bash
sudo systemctl is-active k3s
sudo k3s kubectl get --raw /readyz
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
sudo k3s secrets-encrypt status
```

Tests fonctionnels:

```powershell
.\scripts\phase6\Test-K3sAuditLogging.ps1 -Namespace default
kubectl -n default create secret generic phase6-api-hardening-smoke --from-literal=test=ok
kubectl -n default delete secret phase6-api-hardening-smoke
```

Un rejet de `system:anonymous` est attendu apres `anonymous-auth=false`.

## Encryption at rest

Ne pas activer sans sauvegarde. Procedure cible pour un cluster existant:

```bash
sudo k3s secrets-encrypt status
sudo k3s secrets-encrypt enable
sudo systemctl restart k3s
sudo k3s secrets-encrypt status
```

Sur K3S, l'etat peut rester temporairement `Disabled` avec une rotation stage
`start` apres `enable`. Cela signifie que le mecanisme est prepare mais que la
cle active n'est pas encore en place. Finaliser alors avec:

```bash
sudo k3s secrets-encrypt rotate-keys
sudo systemctl restart k3s
sudo k3s secrets-encrypt status
```

Etat attendu:

```text
Encryption Status: Enabled
Current Rotation Stage: reencrypt_finished
Active Key Type: AES-CBC
```

Si `status` reste `Disabled` apres `enable` et redemarrage, ou si `reencrypt`
renvoie une erreur de type annotation manquante sur le noeud, ne pas relancer en
boucle. Exemple d'erreurs deja observees:

```text
secret-encrypt error ID 21926: missing annotation on node
secret-encrypt error ID 26147: missing annotation on node
```

Verifier d'abord:

```bash
sudo k3s secrets-encrypt status
sudo cat /var/lib/rancher/k3s/server/cred/encryption-config.json
sudo journalctl -u k3s --since "15 minutes ago" --no-pager | grep -i secret-encrypt
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
```

Un provider `identity` dans `encryption-config.json` signifie que le chiffrement
effectif des secrets n'est pas actif.

Verification fonctionnelle:

```bash
sudo systemctl is-active k3s
sudo k3s secrets-encrypt status
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
sudo k3s kubectl -n default create secret generic phase6-encryption-smoke --from-literal=test=ok
sudo k3s kubectl -n default delete secret phase6-encryption-smoke
```

Les fichiers sous `/var/lib/rancher/k3s/server/cred/` deviennent critiques:

- ils contiennent la configuration et la cle de chiffrement;
- ils doivent etre sauvegardes hors Git avec le datastore K3S;
- ils ne doivent pas etre copies dans la documentation ou dans le depot.

## RBAC

Collecte locale:

```powershell
.\scripts\phase6\Collect-Phase6Evidence.ps1
```

Points a revoir:

- bindings vers `cluster-admin`;
- roles donnant acces aux `secrets`;
- roles avec `resources: ["*"]` ou `verbs: ["*"]`;
- droits `create` sur `pods`, `pods/exec`, `pods/attach`, `pods/portforward`;
- droits GitOps ArgoCD, Kyverno, Grafana et Alloy.

Commandes de qualification:

```powershell
kubectl get clusterrolebindings -o json
kubectl get clusterroles -o json
kubectl auth can-i --list --as=system:serviceaccount:kube-system:helm-traefik -n kube-system
```

Decisions Phase 6:

- conserver temporairement les bindings Traefik `cluster-admin` generes par K3S;
- ne pas reduire les roles systeme Kubernetes/K3S sans benchmark et rollback;
- auditer separement les wildcards ArgoCD avant reduction.

## Kyverno et PSA

Verifier les policies:

```powershell
kubectl get clusterpolicies.kyverno.io
kubectl get policyreports -A
kubectl get ns --show-labels
```

Regle de progression:

- ne passer une policy Kyverno en `Enforce` que si elle ne produit plus de
  violation non justifiee;
- traiter `runAsNonRoot` et `seccompProfile: RuntimeDefault` workload par
  workload;
- garder les namespaces systeme et drivers materiels en exception documentee
  tant que leurs contraintes sont confirmees.

## Exploitation securite Loki/Grafana

La collecte des audit logs K3S repose sur Alloy:

- montage read-only de `/var/log/kubernetes/audit`;
- source `loki.source.file "k3s_audit"`;
- label Loki `job="k3s-audit"`.

Apres synchronisation ArgoCD:

```powershell
kubectl -n argocd get application alloy grafana
kubectl -n observability rollout status daemonset/alloy
kubectl -n observability rollout status deployment/grafana
```

Verifier dans Grafana Explore ou via l'API Loki:

```logql
{job="k3s-audit"}
{job="k3s-audit"} | json | objectRef_resource="secrets"
{job="k3s-audit"} | json | objectRef_resource=~"roles|rolebindings|clusterroles|clusterrolebindings"
{job="k3s-audit"} | json | objectRef_subresource=~"exec|attach|portforward"
{job="k3s-audit"} | json | responseStatus_code=~"4..|5.."
```

Dashboard attendu:

- dossier: `Deploy_LGTM`;
- nom: `Deploy_LGTM Kubernetes Security Audit`;
- uid: `deploy-lgtm-k8s-security-audit`.

Activer les alertes seulement apres une periode d'observation pour eviter le
bruit initial.

## Rollback

Si le serveur K3S ne revient pas:

```bash
sudo cp /etc/rancher/k3s/config.yaml.<backup> /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s
sudo journalctl -u k3s -n 200 --no-pager
```

Ne pas enchainer plusieurs durcissements avant d'avoir valide l'etat `Ready` des
noeuds et la sante ArgoCD/Grafana/LGTM.
