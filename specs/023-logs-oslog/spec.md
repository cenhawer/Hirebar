# Feature Specification: Registros con OSLog

**Feature Branch**: `feature/HB-023-logs-oslog`

**Created**: 2026-11-09

**Status**: Draft

**Input**: Constitución, principios IV y VIII. El registro es un archivo propio que escribe cualquier
módulo con E/S directa, sin categorías; eso impide separar adaptadores (todos dependerían del que
escribe el archivo) y obliga a recortarlo en la limpieza semanal.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registro por agente y por área (Priority: P2)

Quien revisa por qué algo no corrió filtra el registro por agente o por área.

**Acceptance Scenarios**:

1. **Given** cualquier evento, **When** se registra, **Then** va al registro del sistema con el
   subsistema de Hirebar y la categoría de su agente o de su área.
2. **Given** el botón "Registro" del panel o "Ver registro" del menú, **When** la persona lo usa,
   **Then** se abre un archivo con los últimos 3 días.
3. **Given** el registro, **When** se escribe, **Then** no lleva datos personales.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El registro MUST usar `os.Logger` con el subsistema `com.vmsoftware.hirebar` y una
  categoría por agente y por área, desde `HirebarApplication` y sin E/S propia.
- **FR-002**: El panel y el menú MUST exportar los últimos 3 días a un archivo y abrirlo.
- **FR-003**: La limpieza semanal MUST NOT recortar un archivo de registro.
- **FR-004**: `HirebarApplication` MUST NOT hacer E/S; un test MUST vigilarlo.

## Success Criteria *(mandatory)*

- **SC-001**: Ningún módulo escribe el registro en un archivo.
