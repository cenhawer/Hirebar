---

description: "Tareas de implementación: aviso de versión nueva"
---

# Tasks: Aviso de versión nueva

- [x] T001 `Resources/version.json` y `GitHubReleaseSettings` validada; entrega por `EngineResources` (FR-001)
- [x] T002 `ReleaseVersion.isNewer(current:latest:)` pura (FR-002)
- [x] T003 `UpdateChecker.check(settings:current:fetcher:)` sobre el puerto `WebPageFetcher` existente (FR-003, FR-004)
- [x] T004 `Controller.checkForUpdate` + revisión diaria desde `Engine`; aviso en el panel con botón "Ver" (US1)
- [x] T005 Tests de `ReleaseVersion`, `UpdateChecker` y `GitHubReleaseSettings` (SC-001, SC-002)
