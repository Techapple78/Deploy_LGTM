# Source source-project

Ce projet peut importer localement les variables Terraform et secrets existants depuis:

```text
C:\Users\USER\Downloads\source-project
```

Les valeurs ne doivent jamais etre imprimees, copiees dans la documentation ou commitees en clair.

## Sources detectees

Variables Terraform:

- `terraform/terraform.tfvars`
- `terraform/credentials.auto.tfvars`
- `secrets/k3s-vsphere-source/terraform/terraform.tfvars`
- `secrets/k3s-vsphere-source/terraform/credentials.auto.tfvars`

Fichiers secrets:

- `secrets/kubeconfig`
- `secrets/argocd-repository-key`
- `secrets/argocd-repository-key.pub`
- `secrets/template-pbk`
- `secrets/template-pvk`

## Commande d'import local

```powershell
.\scripts\import-secrets\import-from-cxxx.ps1 `
  -SourcePath 'C:\Users\USER\Downloads\source-project' `
  -Profile DeployCrewAI `
  -OutputPath '.\secrets\tmp\deploy-crewai-imported-secrets.json'
```

Le fichier de sortie contient les valeurs et reste ignore par Git.

## Generation des SealedSecrets

Prerequis: le controller Sealed Secrets doit exister dans le cluster cible, par defaut `sealed-secrets-controller` dans `kube-system`.

```powershell
.\scripts\import-secrets\generate-sealed-secrets.ps1 `
  -InputFile '.\secrets\tmp\deploy-crewai-imported-secrets.json' `
  -OutputDir '.\secrets\sealed' `
  -Namespace observability
```

Cette commande produit:

- `secrets/sealed/deploy-crewai-terraform-vars.sealedsecret.yaml`
- `secrets/sealed/deploy-crewai-imported-secrets.sealedsecret.yaml`

Ces fichiers chiffres peuvent etre versionnes apres revue.

## Utilisation Terraform locale

Le module `infra/terraform/vsphere` accepte les principaux noms de variables deja presents dans `source-project`, notamment `vsphere_user`, `vsphere_password`, `vsphere_server`, `allow_unverified_ssl`, `datacenter`, `cluster`, `datastore`, `network`, `vm_folder`, `k3s_server_url` et `k3s_token`.

Ne copiez pas les fichiers `.tfvars` importes dans Git. Si une execution Terraform est necessaire, placez un fichier local ignore dans `secrets/tmp/terraform/` ou fournissez les variables via un mecanisme CI/CD securise.

## Variables Terraform reperees

- `vsphere_user`
- `vsphere_password`
- `vsphere_server`
- `allow_unverified_ssl`
- `datacenter`
- `cluster`
- `datastore`
- `network`
- `template_name`
- `vm_folder`
- `esxi_host`
- `vm_name`
- `domain`
- `ipv4_address`
- `ipv4_netmask`
- `ipv4_gateway`
- `dns_servers`
- `ssh_public_key`
- `num_cpus`
- `memory_mb`
- `system_disk_gb`
- `model_disk_gb`
- `gpu_mode`
- `pci_device_id`
- `vgpu_profile`
- `vgpu_attachment_confirmed`
- `nvidia_guest_driver_url`
- `nvidia_guest_driver_sha256`
- `k3s_server_url`
- `k3s_token`
- `k3s_version`
- `nodes`

## Points a confirmer

- Les variables CrewAI doivent-elles seulement servir de reference vSphere/K3S, ou etre reutilisees directement par `infra/terraform/vsphere` ?
- Le `kubeconfig` doit-il rester uniquement local, ou etre scelle pour un usage par un job Kubernetes precis ?
- Les cles `template-pbk` et `template-pvk` sont-elles encore actives et doivent-elles etre conservees ?
