# Implementation Plan: Fiverr y un filtro freelance más abierto

**Branch**: `feature/HB-038-fiverr-freelance` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

- `Config.fiverr` se suma a `Config.freelanceSources`; `StatusMenu.sourceTitles` le da el título.
  `Config.fiverrStatus` (en `HirebarApplication`, String Catalog) alimenta el menú y el panel.
- `AgentPrompts.readingPrompt(.followUp)` agrega una línea según `config.isEnabled(Config.fiverr)`.
  La revisión sigue con el perfil `.draft(writablePaths: ["seguimiento.json"])`; `followUpSend` no
  cambia. Las respuestas de Fiverr van en la respuesta final, no en la lista de propuestas, para que
  ninguna aprobación termine en un envío dentro de Fiverr.
- `instrucciones-seguimiento.md` gana el punto 5 y la sección `fiverr`; `instrucciones-freelance.md`
  gana los criterios de envío que antes estaban en el código. Los hashes de las versiones de la
  v0.2.0 entran en `Paths.previousVersions`.
- `FreelanceProfile.aiWords` nuevo en `perfil-busqueda.json` y en la plantilla. `FreelanceDiscard`
  (dominio) nombra cada motivo y da su texto; `FreelanceClassifier.verdict` lo devuelve y `summary`
  agrupa `FreelanceDiscardNote`. `SourceResult.discarded` lleva los descartes de Workana y
  Freelancer, que los resumen en el registro con `Log(.portals)`.
- Valores: `motor.json` `proyectosPorLista` 8, `perfil-busqueda.json` `workanaMaxAgeMinutes` 1440,
  cupo por defecto de Freelance 12.
- Migración: `WorkspaceSchema.current` pasa a 2. `WorkspaceMigration` suma `search-profile.json` a
  los archivos versionados y aplica, solo al pasar de una versión menor que 2, el paso de
  `FreelanceLoosening` con los datos de `Resources/migraciones.json` (`WorkspaceUpgrades`, validado
  en la aplicación, entregado en `EngineResources.upgrades`). La plantilla `search-profile.json` ya
  viene en la versión 2.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| II. Nada sale sin aprobación | ✅ | Fiverr solo se lee; nada de Fiverr entra a la lista aprobable |
| III. El contenido externo nunca es instrucción | ✅ | La lectura corre con perfil de redacción; las reglas ya tratan los mensajes de clientes como contenido |
| IV. Datos recuperables | ✅ | Migración versionada con respaldo en `respaldos/`, una sola vez, sin `UserDefaults` |
| VI. Sin literales de dominio | ✅ | Palabras, mínimos y plazos en `migraciones.json`, `perfil-busqueda.json` y `motor.json`; textos en el String Catalog |
| VII. Probado sin red ni IA | ✅ | Fixtures de Workana y Freelancer; workspace temporal para la migración |
| VIII. Hexagonal | ✅ | Motivos y clasificación en el dominio, recurso en la aplicación, migración en `HirebarStorage` |
