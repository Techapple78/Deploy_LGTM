# ADR-004: NetworkPolicy default-deny avec CIDR explicites

## Status

Accepted

## Context

Deploy_LGTM execute des composants d'observabilite qui recoivent, stockent et interrogent logs, metriques et traces. La plateforme supporte aussi des integrations de monitoring infra, incluant des flux syslog et SNMP vers des systemes externes comme pfSense, Synology, UniFi, vCenter ou une infrastructure lab equivalente quand elle est configuree.

Les acces reseau doivent etre suffisamment explicites pour l'audit et suffisamment controles pour un depot plateforme partage. Le depot ne doit pas embarquer d'adresses privees reelles ni d'hypotheses locales non documentees.

## Decision

Deploy_LGTM utilise des NetworkPolicies avec une posture default-deny et des regles allow explicites pour les flux necessaires.

Les flux requis incluent, selon les cas:

- egress DNS;
- acces a l'API Kubernetes pour les composants qui en ont besoin;
- acces Grafana vers les datasources Loki, Mimir et Tempo;
- acces Alloy vers Loki, Mimir, Tempo et les exporters;
- ingress Traefik vers Grafana;
- chemins syslog et SNMP explicitement documentes pour le monitoring infra.

Les regles CIDR explicites ameliorent l'auditabilite mais reduisent la portabilite. Les cibles propres a un environnement doivent rester locales, documentees comme exemples ou representees par des valeurs placeholder sures, sauf approbation explicite dans le depot.

## Consequences

Benefices:

- isolation namespace renforcee;
- revue plus claire du rayon d'impact reseau;
- audit securite facilite des flux d'observabilite;
- changements GitOps plus surs car l'intention reseau est visible.

Compromis:

- les regles basees sur des CIDR peuvent etre specifiques a un environnement;
- les policies default-deny demandent une cartographie precise des dependances;
- des regles trop strictes peuvent casser logs, metriques, traces, DNS ou acces API Kubernetes;
- les integrations locales demandent un processus documente de configuration non sensible.

## Alternatives Considered

- Aucune NetworkPolicy, rejete car le trafic observabilite et plateforme resterait trop ouvert.
- Egress allow-all large, rejete comme cible par defaut mais acceptable temporairement lors d'une migration si le risque est documente.
- IP privees d'environnement committees dans Git, rejete sauf anonymisation ou approbation explicite.

## Related ADRs

- ADR-001: Replication MVP et stockage filesystem
- ADR-002: Kyverno progressive enforcement
- ADR-003: Sealed Secrets supply chain
