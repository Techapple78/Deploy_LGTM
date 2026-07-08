# Rapport Phase 5 - Resultats de test

Date: 2026-07-08

## Synthese

Phase 5 est validee sur le perimetre applicatif maitrise `phase5-telemetry-app`.

Statut final: termine.

| Famille | Statut | Resultat |
| --- | --- | --- |
| Tests unitaires | Execute | OK |
| Tests globaux LGTM | Execute | OK |
| Tests de stress | Execute | OK |
| Tests de charge courte | Execute | OK |
| Tests de regression | Execute | OK |

Le test MySQL n'est pas retenu comme critere de cloture Phase 5. Le besoin principal est la consommation effective de la stack LGTM par une application maitrisee, avec logs, metriques, traces, dashboard et NetworkPolicies.

## Commandes executees

Validation repository:

```powershell
.\scripts\Test-Repository.ps1
```

Campagne Phase 5 complete:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\phase5\Test-Phase5Full.ps1 -StressIterations 120 -ChargeDurationSeconds 180
```

## Resultats unitaires

| Test | Resultat | Preuve |
| --- | --- | --- |
| `GET /healthz` | OK | Retour `ok`. |
| `GET /` | OK | Page HTML avec le titre `Deploy_LGTM Phase 5 Telemetry`. |
| `GET /api/work` | OK | JSON `status=ok` avec `trace_id`. |
| `GET /api/error` | OK | Erreur 500 controlee avec `trace_id`. |
| `GET /metrics` | OK | Metriques `phase5_*` exposees. |

Compteurs observes pendant la campagne:

| Metrique | Valeur observee |
| --- | --- |
| `phase5_http_requests_total` | `420` au debut de la campagne complete |
| `phase5_http_errors_total` | `7` au debut de la campagne complete |
| `phase5_otlp_traces_sent_total` | `17` au debut de la campagne complete |
| `phase5_otlp_trace_failures_total` | `0` |

## Resultats globaux LGTM

| Backend | Requete / verification | Resultat |
| --- | --- | --- |
| Loki | `{namespace="phase5-telemetry"} |= "trace_id"` | OK, `loki_streams=1` |
| Mimir | `phase5_http_requests_total{app="phase5-telemetry-app"}` | OK, `mimir_series=1` |
| Tempo | Recherche `service.name=phase5-telemetry-app` | OK, `tempo_traces=5` |
| Grafana | Dashboard `Deploy_LGTM Phase 5 Telemetry Overview` | Deployee via values Grafana |

## Resultats stress

Parametre:

- `StressIterations=120`

Resultat:

- `120` appels nominaux envoyes vers `/api/work`;
- `10` erreurs controlees envoyees vers `/api/error`;
- aucun CrashLoopBackOff observe;
- `phase5-telemetry-app` reste `Running`;
- Alloy reste `Running` sur les noeuds cibles.

## Resultats charge courte

Parametre:

- `ChargeDurationSeconds=180`

Resultat:

- `177` appels nominaux envoyes;
- `11` erreurs controlees envoyees;
- `phase5-telemetry-app` reste `Running`;
- `phase5_otlp_trace_failures_total` reste a `0`;
- Loki, Mimir et Tempo restent interrogeables apres la charge.

Ce test valide une charge courte de stabilisation. Un soak test 24h reste un exercice capacitaire distinct, utile avant production exposee, mais il n'est pas requis pour cloturer la Phase 5 MVP.

## Resultats regression

| Controle | Resultat |
| --- | --- |
| Validation repository | OK |
| Applications ArgoCD Phase 5 et observability | `Synced` / `Healthy` |
| Pod applicatif | `Running`, `0` restart |
| Pods Alloy | `Running`, `0` restart recent |
| Pods Loki/Mimir/Tempo/Grafana | `Running` |
| Logs applicatifs recents | OK, logs JSON avec `trace_id` |
| Secrets en clair | Non detectes par `scripts\Test-Repository.ps1` |

## Incidents et corrections

| Incident | Cause | Correction |
| --- | --- | --- |
| Test HTML initial en faux negatif | Comparaison PowerShell appliquee sur un tableau de lignes | Sortie concatenee avant assertion dans `Test-Phase5Full.ps1` |
| Port-forward bloque en sandbox | Restriction reseau locale de l'environnement d'execution | Campagne executee hors sandbox pour acceder au cluster |

## Conclusion

Phase 5 est terminee.

Les criteres de sortie retenus sont atteints:

- application temoin maitrisee accessible dans le cluster;
- logs applicatifs visibles dans Loki;
- metriques applicatives visibles dans Mimir;
- traces OTLP visibles dans Tempo;
- dashboard Grafana deploye;
- NetworkPolicies Phase 5 en place;
- tests unitaires, globaux, stress, charge courte et regression executes;
- documentation mise a jour.
