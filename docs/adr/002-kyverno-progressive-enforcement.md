# ADR-002: Kyverno progressive enforcement

## Status

Accepted

## Context

Deploy_LGTM utilise Kyverno pour appliquer des garde-fous de securite Kubernetes. La plateforme contient a la fois des manifests maitrises et des charts Helm tiers. Passer toutes les policies en `Enforce` d'un seul coup peut bloquer la reconciliation GitOps, surtout tant que les charts ne sont pas encore ajustes aux Pod Security Standards et au moindre privilege.

Le depot a besoin d'un enforcement securite concret des le MVP, sans rendre la plateforme fragile.

## Decision

L'enforcement Kyverno est progressif.

Les policies a risque eleve suivantes sont appliquees immediatement:

- `disallow-privileged-containers`, qui bloque les conteneurs avec `securityContext.privileged: true`;
- `disallow-latest-tag`, qui bloque les tags d'image mutables `:latest`.

Les autres controles de baseline restent en `Audit` pendant que leur impact operationnel est mesure et corrige workload par workload.

Cette strategie est volontaire. Elle applique d'abord les controles les plus critiques et conserve les autres policies visibles via les resultats d'audit jusqu'a la phase de stabilisation.

## Consequences

Benefices:

- un enforcement securite reel existe pendant le MVP;
- les conteneurs privilegies et tags `latest` sont bloques tot;
- la reconciliation GitOps risque moins d'etre bloquee par des controles encore en calibration;
- les contributeurs peuvent corriger les findings d'audit progressivement.

Compromis:

- la plateforme n'est pas encore totalement enforcee sur tous les controles de baseline;
- l'etat intermediaire doit etre documente et surveille;
- les findings d'audit doivent etre revus regulierement;
- l'enforcement complet reste une tache de stabilisation future.

## Alternatives Considered

- Passer toutes les policies Kyverno en `Enforce` immediatement, rejete car cela peut bloquer des charts tiers et la reprise operationnelle.
- Garder toutes les policies en `Audit`, rejete car cela ne bloque pas les cas les plus dangereux.
- Desactiver Kyverno pendant le MVP, rejete car l'admission control est une exigence securite centrale de la plateforme.

## Related ADRs

- ADR-001: Replication MVP et stockage filesystem
- ADR-003: Sealed Secrets supply chain
- ADR-004: NetworkPolicy default-deny avec CIDR explicites
