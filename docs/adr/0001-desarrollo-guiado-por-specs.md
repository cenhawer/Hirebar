# ADR-0001: Desarrollo guiado por specs con Spec Kit

## Estado

Aceptado · 2026-11-05

## Contexto

Hirebar actúa en nombre de una persona: postula, propone, escribe correos y publica. El código creció
sin specs ni tests de su motor: en un mismo día entró una integración de voz de 952 líneas y salió
completa, sin dejar un test. Las reglas de negocio (qué aviso encaja, qué se aprueba, qué se envía)
solo existen en el código, y 36 de los 57 archivos de `Sources` no tienen ningún test.

## Decisión

Todo cambio de comportamiento parte de una spec aprobada en `specs/NNN-nombre/`, con el ciclo de
GitHub Spec Kit: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
`/speckit-analyze` → `/speckit-implement`. La capa técnica transversal es la constitución
(`.specify/memory/constitution.md`), `ARCHITECTURE.md` y `Lineamientos/`. El comportamiento actual se
documenta primero como specs as-is, que sirven de referencia contra regresiones.

## Consecuencias

- Cada tarea cita su `FR-###`; cada escenario y `SC-###` tiene un test.
- Un PR que toca `Sources/` sin referenciar una spec no pasa el CI (actividad 1.8 del plan).
- El ritmo de entrada de features baja al principio: primero las specs as-is, después los cambios.
- La rama de cada spec se crea a mano como `feature/HB-NNN-nombre`, porque Spec Kit 0.16.5 solo crea
  la carpeta.

## Alternativas consideradas

| Alternativa | Por qué no |
|---|---|
| Seguir sin specs, con issues y PR | Es como se llegó a reglas que solo existen en el código y a features sin tests |
| Flujo de specs propio | Los Lineamientos fijan Spec Kit como motor; un flujo propio queda solo como respaldo |

## Referencias

- Constitución, principios I y VII.
- `Lineamientos/architecture/sdd-conventions.md`.
- `docs/Plan.md`, fase 1.
