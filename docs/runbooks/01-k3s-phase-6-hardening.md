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

## Encryption at rest

Ne pas activer sans sauvegarde. Procedure cible:

```bash
sudo k3s secrets-encrypt status
sudo k3s secrets-encrypt enable
sudo systemctl restart k3s
sudo k3s secrets-encrypt status
```

La rotation de cle doit etre testee hors production:

```bash
sudo k3s secrets-encrypt rotate-keys
sudo systemctl restart k3s
sudo k3s secrets-encrypt status
```

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

## Rollback

Si le serveur K3S ne revient pas:

```bash
sudo cp /etc/rancher/k3s/config.yaml.<backup> /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s
sudo journalctl -u k3s -n 200 --no-pager
```

Ne pas enchainer plusieurs durcissements avant d'avoir valide l'etat `Ready` des
noeuds et la sante ArgoCD/Grafana/LGTM.
