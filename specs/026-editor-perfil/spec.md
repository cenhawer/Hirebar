# Feature Specification: Editor de perfil

**Feature Branch**: `feature/HB-026-editor-perfil`

**Created**: 2026-11-10

**Status**: Draft

**Input**: `docs/Plan.md`, fase 4. El perfil (`perfil.json`) es la única fuente de experiencia, pero
solo las habilidades se editaban desde Ajustes: datos, experiencia, preferencias y variantes de hoja
de vida exigían editar JSON a mano.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Editar el perfil desde Ajustes (Priority: P1)

La persona abre Ajustes → Datos y experiencia y cambia sus datos personales, sus preferencias de
empleo, sus empleos con sus logros y sus hojas de vida, sin tocar JSON.

**Independent Test**: el perfil de la plantilla se carga en el editor, se cambia y se guarda; el
archivo resultante tiene los cambios y conserva lo que el editor no muestra.

**Acceptance Scenarios**:

1. **Given** un `perfil.json`, **When** se abre el editor, **Then** muestra nombre, titular, ciudad,
   país, correo, teléfono, enlaces, cargos buscados, modalidad, disponibilidad, salarios, tarifa,
   empleos con logros y variantes de hoja de vida.
2. **Given** cambios en el editor, **When** se guarda, **Then** se escriben en `perfil.json` con
   `schemaVersion`, y se conservan idiomas, estudios, proyectos, reglas, habilidades y cualquier campo
   que la IA o la persona hayan agregado a un empleo, logro o variante.
3. **Given** un empleo actual, **When** se deja vacía la fecha de salida, **Then** se guarda como
   actual.

### User Story 2 - No guardar un perfil inválido (Priority: P1)

**Acceptance Scenarios**:

1. **Given** un perfil sin nombre, con un correo mal escrito, un empleo sin empresa, una fecha que no
   es AAAA-MM, una salida anterior a la entrada, un logro vacío o una hoja de vida sin identificador,
   sin archivo o repetida, **When** se guarda, **Then** no se escribe nada y Ajustes dice qué arreglar.
2. **Given** un `perfil.json` de una versión más nueva de Hirebar, **When** se guarda, **Then** no se
   sobrescribe.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Ajustes MUST permitir editar datos personales, preferencias, experiencia con logros y
  variantes de hoja de vida.
- **FR-002**: Guardar MUST conservar todo campo de `perfil.json` que el editor no muestra.
- **FR-003**: La validación MUST vivir en el dominio (`ProfileDocument.problems`) y probarse sin interfaz.
- **FR-004**: El guardado MUST pasar por el puerto `ProfileRepository` y respetar la versión del archivo.

## Success Criteria *(mandatory)*

- **SC-001**: Tests de lectura, guardado con conservación de campos, versión más nueva y cada regla de
  validación.
