---

description: "Tareas de implementación: textos y valores fuera del código"
---

# Tasks: Textos y valores fuera del código

## Paso 1: String Catalog

- [x] T001 Textos para la persona con `String(localized:)` en la app, la aplicación, los adaptadores y los títulos del dominio (FR-001, FR-002)
- [x] T002 Textos largos como literales de varias líneas de una sola clave (FR-003)
- [x] T003 `scripts/strings.sh` y `Resources/Localizable.xcstrings`; verificación en el CI y compilación en `bundle.sh` (SC-001)
- [x] T004 Test de puntos de salida (SC-002)

## Paso 2: Valores en configuración

- [x] T005 Perfil de búsqueda por defecto y palabras del filtro de vacantes (`JobScreeningWords`) en `Resources/perfil-busqueda.json`; `workspace/search-profile.json` se lee sobre esa base; el dominio no tiene listas de palabras (FR-004)
- [x] T006 Plazos, intervalos y límites por lista del motor, los radares y el programador en `Resources/motor.json` (`EnginePolicy`); sin ese archivo la app avisa que está incompleta en vez de arrancar (FR-004)
- [x] T007 Ventanas de antigüedad, topes de propuestas y presupuestos descartados de cada portal en `Resources/perfil-busqueda.json` (`FreelancePortalRules`, `JobPortalRules`) (FR-004)
