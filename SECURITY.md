# Security Policy

## Perimetre

Ce depot porte l'infrastructure GitOps `Deploy_LGTM` pour une plateforme K3S/LGTM:

- manifests Kubernetes et Kustomize;
- chart values Helm;
- Argo CD Applications;
- policies Kyverno et NetworkPolicies;
- documentation d'exploitation et de securite.

Les secrets en clair, fichiers `.tfvars`, kubeconfigs, cles privees et configurations locales reelles ne doivent jamais etre versionnes.

## Regles de contribution securite

Avant tout commit:

1. verifier que les fichiers sensibles restent dans `local/`, `secrets/tmp/`, `secrets/plain/` ou dans un coffre externe;
2. ne versionner que des `SealedSecret` chiffres;
3. executer les controles CI locaux quand possible:

```powershell
.\scripts\Test-Repository.ps1
trivy config --severity HIGH,CRITICAL .
```

4. verifier qu'aucune IP, hostname interne, community SNMP ou credential reel n'est present dans les fichiers suivis par Git.

## Baseline de durcissement

Les workloads du projet doivent viser:

- `runAsNonRoot: true`;
- `allowPrivilegeEscalation: false`;
- `readOnlyRootFilesystem: true` quand compatible;
- `capabilities.drop: ["ALL"]`;
- `seccompProfile: RuntimeDefault`;
- resources requests/limits;
- secrets references via `Secret` ou `SealedSecret`, jamais via `ConfigMap`.

Les exceptions doivent etre documentees avec leur justification, leur risque et leur date de relecture.

## Signalement d'un probleme

Pour un incident local ou une fuite potentielle:

1. retirer la donnee sensible du working tree;
2. revoquer ou faire tourner le secret concerne;
3. reecrire l'historique Git si la donnee a ete poussee;
4. forcer un scan complet du depot;
5. documenter la decision dans `docs/07-security.md` ou dans un rapport `docs/reports/`.

## References

- CIS Kubernetes Benchmark: https://www.cisecurity.org/benchmark/kubernetes
- K3s CIS Hardening Guide: https://docs.k3s.io/security/hardening-guide
- K3s CIS Self Assessment: https://docs.k3s.io/security/self-assessment-1.7
- ANSSI - Recommandations de securite relatives au deploiement de conteneurs Docker: https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-au-deploiement-de-conteneurs-docker
- ANSSI - Recommandations pour la mise en place de cloisonnement systeme: https://messervices.cyber.gouv.fr/guides/recommandations-pour-la-mise-en-place-de-cloisonnement-systeme
