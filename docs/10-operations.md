# Operations

## Routines

- Verifier ArgoCD: `kubectl -n argocd get applications`.
- Verifier observabilite: `kubectl -n observability get pods,svc,pvc`.
- Verifier Kyverno: `kubectl -n kyverno get pods`.
- Verifier Sealed Secrets: `kubectl -n kube-system logs deploy/sealed-secrets-controller --tail=100`.

## Acces Grafana

L'acces cible passe par Traefik en HTTPS:

```text
https://grafana.example.local
```

Le poste d'administration doit resoudre ce nom vers l'adresse exposee par Traefik. En environnement lab, ajouter par exemple dans `C:\Windows\System32\drivers\etc\hosts`:

```text
192.0.2.10 grafana.example.local
```

Si le certificat bloque le navigateur ou si l'Ingress n'est pas encore stabilise, utiliser un acces local sans TLS:

```powershell
kubectl -n observability port-forward svc/grafana 3000:80
```

Puis ouvrir:

```text
http://127.0.0.1:3000
```

Les identifiants administrateur Grafana sont stockes dans le secret Kubernetes `observability/grafana-admin`. Quand l'API K3S repond, les recuperer avec:

```powershell
kubectl -n observability get secret grafana-admin -o jsonpath="{.data.admin-user}" | %{ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }

kubectl -n observability get secret grafana-admin -o jsonpath="{.data.admin-password}" | %{ [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
```

Le dashboard applicatif provisionne est attendu dans le dossier Grafana `Deploy_LGTM`, sous le nom:

```text
Deploy_LGTM Sample App Overview
```

## Acces Loki et Mimir

Loki et Mimir ne sont pas exposes publiquement. L'acces cible passe par Grafana et par les datasources provisionnees:

| Backend | Usage | Service interne |
| --- | --- | --- |
| Loki | Logs LogQL | `loki-gateway.observability.svc.cluster.local:80` |
| Mimir | Metriques Prometheus/PromQL | `mimir-gateway.observability.svc.cluster.local:80` |

Dans l'etat actuel du lab, Loki et Mimir ne portent pas de couple utilisateur/mot de passe applicatif dedie. La protection repose sur:

- l'absence d'exposition externe directe;
- les `NetworkPolicy` du namespace `observability`;
- l'acces operateur via `kubectl`;
- l'acces utilisateur via Grafana.

Pour tester Loki depuis le poste d'administration sans exposer le service:

```powershell
kubectl -n observability port-forward svc/loki-gateway 3100:80
```

Exemples de lecture:

```powershell
Invoke-RestMethod "http://127.0.0.1:3100/loki/api/v1/labels"

Invoke-RestMethod "http://127.0.0.1:3100/loki/api/v1/query_range?query=%7Bnamespace%3D%22sample-app%22%7D&limit=10"
```

Pour tester Mimir depuis le poste d'administration:

```powershell
kubectl -n observability port-forward svc/mimir-gateway 9009:80
```

Exemples de lecture:

```powershell
Invoke-RestMethod "http://127.0.0.1:9009/ready"

Invoke-RestMethod "http://127.0.0.1:9009/prometheus/api/v1/query?query=up"
```

Pour pousser des logs vers Loki en test, utiliser l'API push locale apres port-forward:

```powershell
$now = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
$body = @{
  streams = @(
    @{
      stream = @{
        job = "manual-test"
        source = "operator"
      }
      values = @(
        @($now, "test log from operator workstation")
      )
    }
  )
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:3100/loki/api/v1/push" `
  -ContentType "application/json" `
  -Body $body
```

Pour Mimir, l'ecriture directe utilise le protocole Prometheus `remote_write`. Elle est normalement effectuee par Alloy ou un exporter compatible Prometheus. Pour un test externe, preferer un collector/exporter configure en `remote_write` vers:

```text
http://127.0.0.1:9009/api/v1/push
```

Ne pas exposer Loki ou Mimir directement par Ingress tant qu'une strategie d'authentification n'est pas definie. Pour un acces multi-utilisateur, privilegier Grafana ou une passerelle authentifiee.

## Sauvegardes

- Sauvegarder la cle privee Sealed Secrets avec chiffrement fort.
- Sauvegarder les PVC si Loki/Mimir/Tempo utilisent un stockage local.
- Exporter les dashboards Grafana importants vers Git.

## Mise a jour

1. Modifier les values Helm.
2. Executer les validations CI localement si possible.
3. Ouvrir une pull request.
4. Laisser GitHub Actions valider.
5. Merger.
6. Verifier la synchronisation ArgoCD.

## Telemetrie

Le socle doit exposer:

- Etat des pods et redemarrages.
- Volume de logs ingeres par Loki.
- Cardinalite et ingestion Mimir.
- Latence et erreurs Tempo.
- Etat des collecteurs Alloy.

## Diagnostic Loki apres redemarrage brutal

Si `loki-0` apparait en `CrashLoopBackOff` ou en `1/2`, verifier d'abord quel conteneur redemarre:

```powershell
kubectl -n observability describe pod loki-0
kubectl -n observability logs loki-0 -c loki --previous --tail=100
kubectl -n observability logs loki-0 -c loki-sc-rules --previous --tail=100
```

Le conteneur principal `loki` porte le stockage et l'API logs. Le conteneur `loki-sc-rules` est un sidecar qui lit les `ConfigMap` et `Secret` Kubernetes labels `loki_rule` pour injecter des regles Loki. Avec un `NetworkPolicy` default deny, ce sidecar doit pouvoir joindre l'API Kubernetes interne. Le symptome typique est:

```text
HTTPSConnectionPool(host='10.0.0.1', port=443): Max retries exceeded
Connection refused
```

Dans ce cas, verifier que la policy `allow-loki-to-kubernetes-api` est presente:

```powershell
kubectl -n observability get networkpolicy allow-loki-to-kubernetes-api -o yaml
kubectl get svc kubernetes -o wide
kubectl get endpoints kubernetes -o wide
```

La policy autorise Loki vers le service Kubernetes `10.0.0.1:443` et vers l'endpoint API du cluster `192.0.2.10:6443`. Si l'adresse API change, mettre a jour la policy GitOps avant resynchronisation ArgoCD.
