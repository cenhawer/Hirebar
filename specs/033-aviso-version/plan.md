# Implementation Plan: Aviso de versión nueva

**Branch**: `feature/HB-033-aviso-version` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

- `ReleaseVersion.isNewer(current:latest:)` pura en `HirebarApplication`, compara `major.minor.patch`
  tolerando prefijo `v` y etiquetas no numéricas (las trata como "no hay versión nueva").
- `GitHubReleaseSettings` (schemaVersion, owner, repo) decodificado desde `Resources/version.json` por
  `EngineResources`, igual que `ChannelSettings`.
- `UpdateChecker.check(settings:current:fetcher:)` usa el puerto `WebPageFetcher` ya existente contra
  `https://api.github.com/repos/<owner>/<repo>/releases/latest`, parsea `tag_name` y `html_url`, y
  devuelve `UpdateInfo?` (nil ante cualquier falla, sin lanzar).
- `Controller`/`Scheduler` corren `UpdateChecker` una vez al día (mismo patrón que la limpieza
  semanal, con `runState.claim`) y publican el resultado en `PanelModel.update: UpdateInfo?`.
- `PanelView` muestra un aviso en el encabezado cuando `model.update != nil`, con un botón que abre
  `html_url`.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Sin dependencias externas de distribución | ✅ | Solo `URLSession` vía el puerto `WebPageFetcher` ya existente |
| VII. Probado sin red ni IA | ✅ | `ReleaseVersion` y `UpdateChecker` probados con un `WebPageFetcher` de prueba |
