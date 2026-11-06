# ADR-0002: Arquitectura hexagonal con límites por targets de SwiftPM

## Estado

Aceptado · 2026-11-05

## Contexto

Hirebar integra muchas piezas externas que cambian por su cuenta: siete portales con HTML propio,
cuatro motores de IA, la API de Telegram, Chrome, el reconocimiento de voz y ffmpeg. Hoy tiene cuatro
targets en cadena (`Hirebar` → `HirebarEngine` → `HirebarSources` → `HirebarCore`), y el motor usa
singletons (`.shared`) y lee y escribe disco desde cualquier capa. Así las reglas no se pueden
probar sin red ni IA, y separar la lectura de contenido externo de las acciones (constitución,
principio III) no tiene dónde apoyarse.

## Decisión

Arquitectura hexagonal: `HirebarDomain` (entidades y reglas puras), `HirebarApplication` (casos de uso
y puertos), un target por familia de adaptadores (`HirebarTelegram`, `HirebarAI`, `HirebarPortals`,
`HirebarStorage`, `HirebarMedia`) y la app `Hirebar` como raíz de composición. Los límites los impone
SwiftPM: las dependencias declaradas en `Package.swift` solo apuntan hacia el dominio, y un import
que cruza una capa no compila. Solo la raíz de composición instancia adaptadores.

## Consecuencias

- Las reglas y los casos de uso se prueban con dobles de los puertos, sin red, IA, Chrome ni Telegram.
- Agregar un portal, un motor de IA u otro canal es agregar un adaptador, sin tocar el dominio.
- Leer y actuar quedan como casos de uso distintos con puertos distintos.
- Hay que mover y partir casi todos los archivos actuales; el destino de cada uno está en
  `ARCHITECTURE.md` §3.3 y el trabajo en la spec `008-arquitectura-hexagonal`.
- Más targets y más protocolos que hoy: cada uno tiene que justificarse por un puerto real.

## Alternativas consideradas

| Alternativa | Por qué no |
|---|---|
| Mantener los cuatro targets en cadena | No aísla el dominio de la E/S ni permite probar las reglas sin red ni IA |
| Clean Architecture Domain/Data/Presentation | Encaja con apps de datos y pantallas; Hirebar es sobre todo integraciones, y los puertos y adaptadores las modelan de forma directa |
| Capas como carpetas dentro de un solo target | Los límites dependerían de la revisión humana; con targets los vigila el compilador |

## Referencias

- Constitución, principio VIII.
- `ARCHITECTURE.md` §2 y §3.
- `docs/Plan.md`, spec `008-arquitectura-hexagonal`.
