# ADR-001: Replication MVP et stockage filesystem

## Status

Accepted

## Context

Deploy_LGTM demarre comme plateforme GitOps de lab et MVP pour Grafana, Loki, Mimir, Tempo et Alloy sur K3S/vSphere. Le premier objectif est de valider le flux GitOps, l'ingestion observabilite, les dashboards, les controles securite et la documentation d'exploitation sans surconsommer les ressources du lab.

La haute disponibilite et le stockage objet augmenteraient la maturite production, mais ajoutent aussi des dependances operationnelles, du sizing, de la configuration stockage et des modes de panne qui ne sont pas necessaires pour la premiere boucle de validation.

## Decision

Le MVP utilise une approche mono-replica.

Loki peut fonctionner en mode `SingleBinary`. Mimir, Tempo, Grafana, Alloy et les composants d'observabilite sont initialement dimensionnes pour un contexte lab/MVP. Le stockage filesystem est accepte pour la validation initiale.

Ce n'est pas la cible production.

Une phase future devra introduire:

- un stockage objet compatible S3, par exemple S3 ou MinIO;
- un facteur de replication superieur ou egal a 3 quand le composant le supporte;
- une tolerance de panne sur les noeuds et backends de stockage;
- des caches et du tuning du query path;
- des tests explicites de backup et restauration.

## Consequences

Benefices:

- deploiement et troubleshooting plus simples;
- validation MVP plus rapide;
- consommation CPU, memoire et stockage plus faible;
- moins de dependances externes.

Compromis:

- aucune garantie de haute disponibilite;
- une panne du stockage local peut causer une perte de donnees;
- capacite et retention limitees;
- performances et comportements de panne production non pleinement representes.

## Alternatives Considered

- HA production-like des la premiere iteration, rejete car cela ralentirait la validation et augmenterait la complexite du lab.
- Stockage objet des la premiere iteration, rejete tant que retention, sizing et restauration ne sont pas clarifies.
- Aucun stockage persistant, rejete car Grafana, Loki, Mimir et Tempo doivent donner des signaux de persistance meme pendant le MVP.

## Related ADRs

- ADR-002: Kyverno progressive enforcement
- ADR-003: Sealed Secrets supply chain
- ADR-004: NetworkPolicy default-deny avec CIDR explicites
