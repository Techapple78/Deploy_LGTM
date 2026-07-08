# Contribuer a Deploy_LGTM

## Bienvenue

Deploy_LGTM est un socle GitOps pour exploiter une stack d'observabilite LGTM sur K3S/vSphere. Le depot est destine a etre utilise par une equipe multi-contributeurs, avec une gouvernance claire, des validations reproductibles et une approche securite des la conception.

Ce depot contient des manifests Kubernetes, des values Helm, des Applications Argo CD, des policies Kyverno, des NetworkPolicies, un socle Terraform, des scripts et de la documentation d'exploitation.

## Environnement de developpement

Travaillez depuis une branche dediee et validez vos changements localement avant d'ouvrir une pull request.

Bootstrap recommande:

```powershell
.\scripts\bootstrap\Install-LocalTools.ps1
```

Ce script aide a installer ou verifier l'outillage local quand c'est possible. Sur un poste administre, confirmez les droits d'installation avec l'administrateur.

## Prerequis locaux

Les outils suivants doivent etre disponibles dans le shell:

- `kubectl`
- `helm`
- `kustomize`
- `kubeconform`
- `yamllint`

Outils optionnels mais recommandes:

- `trivy`
- `gitleaks`
- `pre-commit`

## Conventions de commit

Utilisez Conventional Commits:

```text
<type>(<scope>): <resume>
```

Exemples:

```text
feat(kyverno): enforce privileged container policy
docs(adr): document MVP storage trade-offs
security(netpol): tighten observability egress rules
```

Les commits doivent rester atomiques. Chaque commit doit porter un changement coherent et identifiable.

## Workflow de branches

Utilisez des branches courtes:

- `feature/<nom>`
- `fix/<nom>`
- `docs/<nom>`

Ne poussez pas directement sur `main`.

## Workflow de pull request

Avant de demander une review:

1. Rebasez ou mettez a jour votre branche depuis `main`.
2. Executez les validations disponibles.
3. Verifiez qu'aucun secret en clair, cle privee, kubeconfig, `.tfvars` ou valeur locale reelle n'a ete ajoute.
4. Mettez a jour la documentation si le changement a un impact de deploiement, d'exploitation, de securite ou de troubleshooting.

Une pull request requiert:

- une CI verte;
- une review avant merge;
- une description claire de l'impact operationnel ou securite;
- des liens vers les issues, ADRs ou rapports associes si necessaire.

## Definition of Done

Un changement est termine quand:

- le YAML est lintable;
- les manifests Kubernetes sont validables;
- les charts Helm se rendent sans erreur;
- aucun secret en clair n'est present;
- la documentation est mise a jour en cas d'impact operationnel;
- les commits sont atomiques;
- le comportement GitOps est compris, y compris l'impact prune ou sync;
- les notes de rollback ou de reprise sont indiquees pour les changements a risque.

## Regles de review

Les reviewers doivent porter une attention particuliere a:

- toute regression securite;
- l'exhaustivite et le moindre privilege des NetworkPolicies;
- le mode, le perimetre et l'impact operationnel des policies Kyverno;
- l'usage de Sealed Secrets et l'absence de secrets en clair;
- la coherence GitOps entre Applications Argo CD et chemins `platform/`;
- l'exactitude de la documentation;
- le rayon d'impact sur K3S, l'observabilite et l'ingress;
- la necessite eventuelle de creer un ADR.

## Signaler une question ou un probleme

Utilisez les issues GitHub ou les commentaires de pull request pour signaler:

- un echec de deploiement;
- une violation de policy;
- un manque documentaire;
- une ambiguite d'ownership;
- une suspicion d'exposition de secret;
- un sujet securite ou hardening.

Pour les sujets sensibles, ne publiez pas de secret ni de detail exploitable dans un commentaire public. Faites tourner immediatement les credentials exposes et documentez la remediation.

## Licence

Aucun fichier de licence n'est actuellement present dans ce depot. Ne supposez pas de droit de reutilisation au-dela de l'autorisation explicite du proprietaire du depot.
