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
