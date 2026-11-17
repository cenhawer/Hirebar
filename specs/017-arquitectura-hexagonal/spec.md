# Feature Specification: Arquitectura hexagonal

**Feature Branch**: `feature/HB-017-*` (una rama por paso)

**Created**: 2026-11-09

**Status**: Draft

**Input**: Constitución, principio VIII, y `ARCHITECTURE.md` §3. El código vive en cuatro targets en
cadena: las entidades se mezclan con la E/S, los adaptadores se llaman entre sí y 104 usos de `.shared`
hacen que nada se pueda probar sin el disco, Telegram o la IA reales.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reglas del producto sin E/S (Priority: P1)

Quien mantiene Hirebar prueba las reglas (encaje de avisos, agentes, perfil, cuentas, cupos,
alineación de la voz) sin tocar disco, red ni procesos.

**Independent Test**: un test recorre `Sources/HirebarDomain` y falla si aparece `FileManager`,
`Process`, `URLSession`, `UserDefaults`, lectura o escritura de archivos o el registro.

**Acceptance Scenarios**:

1. **Given** las entidades y reglas puras, **When** se compila, **Then** viven en `HirebarDomain` y no
   importan ningún otro target.
2. **Given** una entidad que antes leía disco (perfil, cuentas, perfil de búsqueda, agentes, portales,
   cupos), **When** se separa, **Then** la entidad queda en el dominio y su lectura y escritura en un
   almacén del adaptador, con la misma API para quien la usa.

### User Story 2 - Un target por familia de adaptadores (Priority: P1)

**Acceptance Scenarios**:

1. **Given** Telegram, notificaciones, almacenamiento, portales, IA y medios, **When** se compila,
   **Then** cada familia es su propio target, depende solo de `HirebarApplication` y no importa otro
   adaptador.

### User Story 3 - Casos de uso y raíz de composición (Priority: P1)

**Acceptance Scenarios**:

1. **Given** el motor, **When** se reorganiza, **Then** los casos de uso viven en `HirebarApplication`
   y hablan con los adaptadores por puertos (`ARCHITECTURE.md` §3.1).
2. **Given** la app, **When** arranca, **Then** la raíz de composición crea los adaptadores y los
   conecta; no hay `.shared` fuera de ella.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `HirebarDomain` MUST contener las entidades y reglas puras y MUST NOT hacer E/S ni
  importar otros targets; un test MUST vigilarlo.
- **FR-002**: Cada familia de adaptadores MUST ser un target que depende solo de `HirebarApplication`
  (y `HirebarDomain`).
- **FR-003**: Los casos de uso MUST vivir en `HirebarApplication` y usar los puertos de §3.1.
- **FR-004**: Solo la raíz de composición MUST crear adaptadores; no MUST haber `.shared` propios
  fuera de ella.
- **FR-005**: El comportamiento para la persona MUST NOT cambiar; cada paso MUST pasar la suite
  completa.

## Success Criteria *(mandatory)*

- **SC-001**: Cero usos de E/S en `HirebarDomain` (test).
- **SC-002**: Cero `.shared` propios fuera de la raíz de composición al cerrar el paso 3.
