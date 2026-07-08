# ADR-003: Sealed Secrets supply chain

## Status

Accepted

## Context

Deploy_LGTM est gere par GitOps. Le depot doit decrire l'etat desire du cluster sans stocker de secrets en clair dans Git.

La plateforme a besoin d'un workflow secrets suffisamment simple pour le MVP, compatible avec la reconciliation Argo CD et explicite pour les contributeurs.

## Decision

Deploy_LGTM utilise Sealed Secrets pour versionner dans Git des secrets Kubernetes chiffres.

Regles:

- ne jamais committer de secret en clair;
- garder les valeurs sources en clair localement ou dans un coffre externe approuve;
- versionner uniquement des objets `SealedSecret`;
- confiner la cle privee Sealed Secrets au cluster;
- traiter la sauvegarde de la cle privee Sealed Secrets comme une exigence critique de reprise.

## Consequences

Benefices:

- Git reste la source de verite pour les objets secrets chiffres;
- Argo CD peut appliquer l'etat secret sans recevoir de valeurs en clair depuis Git;
- le workflow est plus simple qu'une plateforme complete de gestion de secrets pendant le MVP;
- les contributeurs peuvent relire les metadonnees des objets secrets sans voir les valeurs.

Compromis:

- le dechiffrement depend de la cle privee cote cluster;
- perdre la cle privee rend les secrets scelles existants non recuperables depuis Git seul;
- rotation et reprise d'activite doivent etre testees;
- Sealed Secrets ne remplace pas une strategie de coffre entreprise a long terme.

## Alternatives Considered

- Vault: option entreprise robuste, mais plus lourde a deployer, operer, sauvegarder et integrer pendant le MVP.
- SOPS: bonne approche Git-native, mais demande des decisions de gestion de cles hors perimetre MVP.
- External Secrets Operator: utile avec un backend secrets existant, mais ajoute une dependance non requise pour la validation GitOps initiale.
- Secrets en clair ou fichiers `.env` committes: rejetes car le risque d'exposition est inacceptable.

## Related ADRs

- ADR-001: Replication MVP et stockage filesystem
- ADR-002: Kyverno progressive enforcement
- ADR-004: NetworkPolicy default-deny avec CIDR explicites
