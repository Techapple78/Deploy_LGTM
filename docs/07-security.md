# Securite

## Regles

- Aucun secret en clair dans Git.
- Les exports venant de `C:\XXX` restent locaux.
- Les fichiers temporaires sont ecrits dans `secrets/tmp/`, ignore par Git.
- Seuls les `SealedSecret` chiffres peuvent etre versionnes.
- GitHub Actions execute des controles de fuite de secrets.

## Rotation des secrets

1. Modifiez le secret source dans `C:\XXX`.
2. Relancez `import-from-cxxx.ps1`.
3. Relancez `generate-sealed-secrets.ps1`.
4. Commitez le nouveau `SealedSecret`.
5. Laissez ArgoCD synchroniser.
6. Redemarrez les workloads si l'application ne recharge pas les secrets dynamiquement.

## Perte de la cle privee Sealed Secrets

Si la cle privee du controller est perdue, les SealedSecrets existants ne peuvent plus etre dechiffres.

Plan de reprise:

1. Reinstaller ou restaurer le controller Sealed Secrets.
2. Recuperer les secrets depuis la source locale autorisee `C:\XXX` ou depuis un coffre hors Git.
3. Regenerer tous les SealedSecrets avec la nouvelle cle publique.
4. Commiter les nouveaux fichiers chiffres.
5. Resynchroniser ArgoCD.

Decision humaine requise: definir une sauvegarde chiffree de la cle privee Sealed Secrets et son proprietaire.

## Controle avant commit

Avant tout commit, lancez un scan de secrets avec Gitleaks ou Trivy, puis verifiez manuellement que les fichiers hors `secrets/tmp/` et hors `secrets/sealed/*.yaml` ne contiennent aucune cle privee, aucun token et aucun fichier `.tfvars` sensible.

La commande ne doit retourner aucune valeur sensible en clair. Les fichiers dans `secrets/tmp/` restent locaux et ignores par Git.

## Durcissement recommande

- Activer TLS partout.
- Ajouter Pod Security Admission `restricted` par namespace compatible.
- Ajouter NetworkPolicies apres inventaire des flux.
- Signer les images et verifier les signatures en admission.
- Ajouter SBOM et scan de dependances.

Le plan detaille avant l'iteration 4 est documente dans [08-security-hardening-plan.md](08-security-hardening-plan.md).

Les controles CI `lint`, `render`, `security` et `sbom` sont detailles dans [06-ci-workflows.md](06-ci-workflows.md).

## Audit CIS / ANSSI - 2026-07-07

### Portee

Audit documentaire et statique du depot `Deploy_LGTM`.

Ce controle couvre:

- manifests Kubernetes versionnes;
- GitOps Argo CD;
- gestion des secrets;
- NetworkPolicies;
- Kyverno et Pod Security Admission;
- CI `lint`, `render`, `security`, `sbom`;
- documentation d'exploitation.

Ce controle ne remplace pas un audit runtime complet du cluster. Les points K3S host, API server, audit logs et datastore doivent etre verifies sur les noeuds.

### Decision applicative

L'application temoin externe precedemment utilisee a ete retiree du perimetre GitOps. Elle n'est pas maintenue, n'est pas maitrisee par le projet et ne doit pas rester une dependance de validation securite.

Le projet conserve uniquement un modele documentaire pour integrer plus tard une application maitrisee. Toute future application de test devra passer par revue securite, scan CI, image epinglee, SBOM et instrumentation explicite.

### Resultat du scan global

Le scan global du depot passe sur les manifests maitrises, mais les manifests Helm rendus dans `rendered/` exposent encore des ecarts a traiter par values Helm ou exceptions documentees:

| Composant rendu | Ecart principal | Risque | Traitement |
| --- | --- | --- | --- |
| Alloy | `KSV-0041` ClusterRole avec acces secrets; `KSV-0014` root filesystem non read-only; `KSV-0118` security context par defaut. | RBAC sensible et execution trop permissive. | Reduire RBAC Alloy si compatible, puis ajouter securityContext via values Alloy. |
| Grafana | `KSV-0014` root filesystem non read-only sur init, app et pod de test; `KSV-0118` sur pod de test. | Ecriture locale et contexte implicite. | Durcir values Grafana, desactiver ou durcir Helm tests. |
| Loki | `KSV-0041` ClusterRole avec acces secrets; `KSV-0014`/`KSV-0118` sur Helm test. | RBAC sensible et pod de test permissif. | Verifier besoin du sidecar rules; reduire RBAC ou accepter temporairement avec justification. |
| Mimir | `KSV-0014` sur smoke-test. | Pod de test moins durci. | Durcir ou desactiver smoke-test selon usage. |
| Tempo | `KSV-0014` sur StatefulSet Tempo. | Root filesystem ecrivable. | Tester `readOnlyRootFilesystem` avec volumes dedies pour donnees/temp. |

Ces findings empechent de declarer le perimetre LGTM entier conforme a une posture `restricted` stricte.

### Lecture CIS / K3S

| Domaine CIS/K3S | Etat actuel projet | Niveau | Action |
| --- | --- | --- | --- |
| Secrets | Sealed Secrets, fichiers sensibles ignores, historique purge des IP/valeurs exposees. | Bon | Tester restauration et rotation exceptionnelle. |
| Workloads | Sample app durcie; charts tiers a verifier par rendu Helm. | Moyen+ | Etendre la baseline aux values Helm quand compatible. |
| Admission | PSA `baseline` et Kyverno en `Audit`. | Bon MVP | Passer progressivement certaines policies en `Enforce`. |
| Reseau | Default deny et allowlists sur `observability`. | Moyen+ | Completer Argo CD, Kyverno et flux internes LGTM. |
| Supply chain | Trivy, SBOM, lint/render CI. | Bon MVP | Ajouter signature/verif images internes futures. |
| RBAC | Composants standards Argo/Kyverno/Sealed Secrets. | A auditer | Exporter et revoir ClusterRole/Binding. |
| Audit logs API | Non prouve par le depot. | Ecart | Verifier configuration K3S `audit-policy-file`. |
| Encryption at rest | Non prouve par le depot. | Ecart | Verifier `secrets-encryption` K3S. |
| Durcissement OS | Hors depot. | Ecart | Audit GNU/Linux, SSH, firewall, updates, comptes. |

### Lecture ANSSI

Les recommandations ANSSI applicables au projet se traduisent ainsi:

| Principe ANSSI | Application Deploy_LGTM | Etat |
| --- | --- | --- |
| Cloisonnement | Namespaces, NetworkPolicies, separation GitOps/observability. | En cours |
| Moindre privilege | A appliquer aux workloads maitrises et aux charts tiers compatibles. | En cours |
| Maitrise des secrets | Pas de secret clair dans Git, Sealed Secrets, sauvegarde externe de la cle. | Bon |
| Durcissement systeme | A traiter sur les noeuds K3S et l'hyperviseur. | A faire hors depot |
| Journalisation | LGTM collecte logs/metrics/traces; audit API Kubernetes a confirmer. | Partiel |
| Maintien en condition de securite | CI security + SBOM; suivi CERT/editeurs a formaliser. | Partiel |

### Ecarts principaux

1. La conformite des charts tiers rendus n'est pas encore garantie au niveau `restricted`.
2. L'audit CIS node/control-plane K3S n'est pas versionne dans le depot.
3. Les policies Kyverno restent majoritairement en `Audit`.
4. Les NetworkPolicies ne couvrent pas encore exhaustivement tous les namespaces systeme.
5. La verification de signatures d'images n'est pas encore activee en admission.

### Plan d'action

1. Executer un scan complet:

```powershell
.\scripts\Test-Repository.ps1
trivy config --severity HIGH,CRITICAL .
```

2. Exporter l'etat runtime:

```powershell
kubectl get ns --show-labels
kubectl get clusterpolicy,policy -A
kubectl get policyreport,clusterpolicyreport -A
kubectl get networkpolicy -A
```

3. Auditer K3S selon CIS:

```powershell
kubectl get nodes -o wide
kubectl -n kube-system get pods
```

Puis executer `kube-bench` ou le guide K3S CIS Self Assessment sur les noeuds.

4. Remedier par ordre de risque:

- secrets et donnees sensibles;
- pods privilegies ou root;
- hostNetwork/hostPID/hostIPC;
- absence de NetworkPolicy sur namespaces exposes;
- images non epinglees ou non signees;
- audit logs et encryption at rest.

5. Enforcer progressivement:

- garder `restricted` en `audit/warn` tant que des warnings existent;
- passer Kyverno en `Enforce` policy par policy;
- commencer par les workloads internes maitrises;
- documenter chaque exception.

### Criteres Go / No-Go

Go pour durcissement suivant si:

- scan Trivy HIGH/CRITICAL propre sur les manifests maitrises;
- pas de secret clair dans Git;
- Argo CD synchronise sans drift;
- Grafana, Loki, Mimir, Tempo et Alloy restent disponibles;
- rollback GitOps identifie.

No-Go si:

- warning PSA/Kyverno non compris;
- flux reseau non cartographie;
- secret ou IP reelle detectee dans Git;
- absence de sauvegarde/restauration Sealed Secrets;
- impact applicatif non teste apres changement securityContext.

## Credentials Loki et Mimir

Dans le lab actuel, Loki et Mimir ne doivent pas etre consideres comme des services publics authentifies par login/mot de passe. Leur protection vient du perimetre Kubernetes:

- services internes `ClusterIP`;
- acces indirect par Grafana;
- acces operateur par `kubectl port-forward`;
- filtrage par `NetworkPolicy`.

Ne pas publier de credentials Loki/Mimir dans Git. Si une authentification dediee est ajoutee plus tard, les secrets devront etre stockes hors Git puis versionnes uniquement sous forme de `SealedSecret`.

Avant toute exposition externe de Loki ou Mimir, definir au minimum:

1. une strategie TLS;
2. une authentification explicite;
3. une autorisation par role ou tenant;
4. une politique de retention;
5. un controle des flux entrants par `NetworkPolicy` et par Ingress/Gateway.

## Sources

- CIS Kubernetes Benchmark: https://www.cisecurity.org/benchmark/kubernetes
- K3s CIS Hardening Guide: https://docs.k3s.io/security/hardening-guide
- K3s CIS Self Assessment: https://docs.k3s.io/security/self-assessment-1.7
- ANSSI - Recommandations de securite relatives au deploiement de conteneurs Docker: https://messervices.cyber.gouv.fr/guides/recommandations-de-securite-relatives-au-deploiement-de-conteneurs-docker
- ANSSI - Recommandations pour la mise en place de cloisonnement systeme: https://messervices.cyber.gouv.fr/guides/recommandations-pour-la-mise-en-place-de-cloisonnement-systeme
