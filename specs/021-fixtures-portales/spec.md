# Feature Specification: Fixtures de portales

**Feature Branch**: `feature/HB-021-fixtures-portales`

**Created**: 2026-11-10

**Status**: Draft

**Input**: Constitución, principio VII. Los lectores de portales bajaban las páginas con `Net` y no
tenían tests: un cambio en el HTML de un portal dejaba de avisar sin que nada fallara.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cada lector probado contra una página guardada (Priority: P1)

**Independent Test**: los tests leen `Tests/Fixtures/portals/` con un lector de páginas falso y una
hora fija, sin red.

**Acceptance Scenarios**:

1. **Given** la búsqueda guardada de LinkedIn, **When** se lee, **Then** salen sus vacantes con enlace
   a la vacante, lo ya visto se salta y la vacante guardada da descripción y ubicación.
2. **Given** Workana, **When** se lee, **Then** salen los resultados embebidos y el número de
   propuestas del proyecto.
3. **Given** Computrabajo y elempleo, **When** se leen, **Then** salen las ofertas con su
   identificador, título y enlace, y solo se avisa lo remoto.
4. **Given** Magneto, Freelancer y Get on Board, **When** se leen, **Then** salen sus ofertas dentro de
   su ventana de tiempo; fuera de ella, o si piden inglés alto, no.

### User Story 2 - Los lectores rotos se arreglan (Priority: P1)

**Acceptance Scenarios**:

1. **Given** el HTML actual de Computrabajo (identificador entre comillas simples y modalidad con
   clases extra), **When** se lee, **Then** reconoce las ofertas y su modalidad.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Cada lector MUST recibir el lector de páginas (`WebPageFetcher`) y, si compara fechas,
  la hora (`PortalClock`); `PortalAccess.bundled` los arma con `NetPageFetcher` y la hora real.
- **FR-002**: Cada portal MUST tener al menos un fixture guardado y un test contra él.
- **FR-003**: Los fixtures MUST guardar solo lo que usa el lector; de Freelancer no se guardan datos de
  usuarios salvo si el pago está verificado.
- **FR-004**: Computrabajo y elempleo MUST separar la lectura del HTML (`offers(in:)`) del filtrado.

## Assumptions

- Computrabajo solo entrega en el HTML las dos primeras ofertas de cada búsqueda; el resto se arma en
  el navegador. elempleo no marca las ofertas remotas en el listado: solo avisa las que lo dicen en
  el título.

## Success Criteria *(mandatory)*

- **SC-001**: Los siete lectores tienen test contra su fixture y la suite corre sin red.
