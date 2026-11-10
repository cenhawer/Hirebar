# Feature Specification: Textos y valores fuera del código

**Feature Branch**: `feature/HB-024-string-catalog`, `feature/HB-024-valores`

**Created**: 2026-11-10

**Status**: Draft

**Input**: `.claude/rules/swift.md` (ningún texto para la persona como literal; plazos, umbrales,
listas de palabras y rutas en configuración). Los textos de Telegram, el panel, Ajustes y los avisos
eran `String` sueltos y las palabras de búsqueda y los plazos vivían en el código.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Textos en el String Catalog (Priority: P1)

**Independent Test**: `scripts/strings.sh --check` confirma que `Resources/Localizable.xcstrings` tiene
todos los textos del código, y un test falla si un punto de salida recibe un literal.

**Acceptance Scenarios**:

1. **Given** una respuesta de Telegram, un estado, una alerta, un aviso o un error que ve la persona,
   **When** se escribe en el código, **Then** pasa por `String(localized:)` o por `LocalizedStringKey` en
   SwiftUI, y su texto está en el catálogo.
2. **Given** el catálogo, **When** se arma la app, **Then** se compila dentro de `Contents/Resources`.
3. **Given** un texto nuevo sin catálogo actualizado, **When** corre el CI, **Then** falla.

### User Story 2 - Valores en configuración (Priority: P2)

**Acceptance Scenarios**:

1. **Given** las palabras de búsqueda, los descartes, los plazos y los tiempos de espera, **When** se
   necesitan, **Then** se leen de recursos del bundle en lugar de constantes en el código.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Todo texto para la persona MUST pasar por el String Catalog (`Resources/Localizable.xcstrings`,
  idioma base español).
- **FR-002**: Los registros y los mensajes para la IA MUST NOT pasar por el catálogo: no son textos para
  la persona.
- **FR-003**: Un texto largo MUST ser una sola clave aunque ocupe varias líneas en el código.
- **FR-004**: Palabras de búsqueda, plazos y tiempos de espera MUST vivir en recursos versionados.

## Success Criteria *(mandatory)*

- **SC-001**: `scripts/strings.sh --check` en verde en el CI.
- **SC-002**: Cero literales en `reply`, `tell`, `setStatus`, `askPerson`, `.problem`, `.failed`,
  alertas y errores (test).
