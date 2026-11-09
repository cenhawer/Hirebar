# Feature Specification: Parser de comandos

**Feature Branch**: `feature/HB-013-parser-comandos`

**Created**: 2026-11-09

**Status**: Draft

**Input**: Spec `008-telegram-y-comandos`. La lectura de los comandos de Telegram vive mezclada con sus
acciones en un mismo método, sin tests, con listas de verbos escritas en el código, y `si`, `ok`, `no`
y `envia` sirven a la vez para listas y para correos.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Un verbo, un comando (Priority: P1)

La persona escribe lo mismo de siempre y cada palabra hace una sola cosa.

**Why this priority**: un verbo con dos significados puede aprobar la lista equivocada.

**Independent Test**: con el vocabulario del bundle, cada texto de la tabla de pruebas produce un único
comando y destino; ningún verbo aparece en dos comandos.

**Acceptance Scenarios**:

1. **Given** `si`, `si 1 3`, un botón `si:<lista>` o una respuesta citando un aviso, **When** llega,
   **Then** se aprueba la lista indicada (la última, la del botón o la citada).
2. **Given** `si correos`, `envia correos 1 3` o `no correos`, **When** llega, **Then** el comando es
   el mismo que sin `correos` y el destino es la última lista de correos.
3. **Given** un texto que no es comando, **When** llega, **Then** se responde con la ayuda.
4. **Given** una nota de voz, **When** llega, **Then** entra por el mismo parser como nota de voz.
5. **Given** un vocabulario con un verbo repetido, **When** la app lo carga, **Then** lo rechaza.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La lectura de comandos MUST ser una función pura en `HirebarApplication`, sin estado ni
  E/S, que devuelve el comando, el destino, los números, las palabras y el resto del texto.
- **FR-002**: Los verbos MUST vivir en `Resources/comandos.json`; ningún verbo MUST pertenecer a dos
  comandos.
- **FR-003**: La palabra `correos` MUST cambiar el destino, no el comando.
- **FR-004**: Las notas de voz MUST entrar por el mismo parser.
- **FR-005**: Cada comando MUST tener al menos un caso en la tabla de pruebas.

## Success Criteria *(mandatory)*

- **SC-001**: Ningún verbo del vocabulario pertenece a dos comandos.
- **SC-002**: El 100% de los comandos de `ARCHITECTURE.md` §4.2 tiene un caso en la tabla de pruebas.
