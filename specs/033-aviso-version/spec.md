# Feature Specification: Aviso de versión nueva

**Feature Branch**: `feature/HB-033-aviso-version`

**Created**: 2026-11-16

**Status**: Draft

**Input**: Constitución (sin dependencias externas de distribución). Hirebar no avisaba cuando salía
una versión nueva en GitHub; la persona tenía que revisar el repositorio a mano.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - La persona se entera de una versión nueva (Priority: P1)

**Independent Test**: con una versión publicada más nueva que la instalada, el panel muestra un
aviso con un botón que abre la página de esa versión; sin versión nueva, no aparece nada.

**Acceptance Scenarios**:

1. **Given** una versión publicada en GitHub mayor que `CFBundleShortVersionString`, **When** corre
   la revisión periódica, **Then** el panel muestra "Hay una versión nueva" con un botón que abre su
   página de GitHub.
2. **Given** la versión publicada es igual o anterior a la instalada, **When** corre la revisión,
   **Then** el panel no muestra ningún aviso.
3. **Given** GitHub no responde o la respuesta no trae una versión reconocible, **When** corre la
   revisión, **Then** no pasa nada visible (no hay aviso ni error); se reintenta en la próxima
   revisión.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `Resources/version.json` MUST define el repositorio de GitHub a consultar
  (`schemaVersion`, dueño, nombre) sin que el repositorio quede escrito en el código.
- **FR-002**: La comparación de versiones MUST sigue el orden numérico de `major.minor.patch`
  (`2.1` es más nueva que `2.0.9`), tolerando un prefijo `v`.
- **FR-003**: La revisión MUST usa solo `URLSession` (sin librerías de actualización externas) contra
  la API pública de releases de GitHub.
- **FR-004**: Una respuesta sin red, sin releases, o con una etiqueta no reconocible AS A VERSION
  MUST no produce ningún aviso ni falla visible.

## Success Criteria *(mandatory)*

- **SC-001**: Tests de `ReleaseVersion.isNewer(current:latest:)` con versiones iguales, mayores,
  menores, con y sin prefijo `v`, y con etiquetas no numéricas.
- **SC-002**: Tests de `UpdateChecker` con un `WebPageFetcher` de prueba: release más nueva, igual,
  sin red, JSON inválido.
