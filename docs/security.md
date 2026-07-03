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

Le plan detaille avant l'iteration 4 est documente dans [security-hardening-plan.md](security-hardening-plan.md).
