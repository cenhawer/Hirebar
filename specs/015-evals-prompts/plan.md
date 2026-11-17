# Implementation Plan: Evals de prompts

**Branch**: `feature/HB-015-evals-prompts` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

## Summary

`RuleContractTests` revisa las cláusulas de cada regla. `EvalGrader` (puro, en `HirebarApplication`)
evalúa una respuesta contra lo esperado de un caso. `EvalTests` corre el evaluador sobre las
respuestas grabadas en el CI y prueba que detecta inyecciones obedecidas, acciones no permitidas y
cifras inventadas; `LiveEvalTests` corre los mismos casos con `claude -p` y el perfil `read` cuando
`HIREBAR_LIVE_EVALS=1`. Se agregó la cláusula contra la inyección a las reglas de contenido y de envío
de seguimientos, y la prohibición de inventar a la de prospección, con sus huellas anteriores.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| III. Contenido externo nunca es instrucción | ✅ | Cláusula exigida por el CI y casos de inyección |
| VII. Probado sin red ni IA | ✅ | El CI usa respuestas grabadas; la IA real solo en local y a pedido |

## Complexity Tracking

| Desvío | Por qué | Alternativa descartada |
|---|---|---|
| Los evals con IA real no corren en el CI | El CI no tiene sesión de Claude Code ni presupuesto por corrida | Grabar y reproducir cada respuesta en cada PR (no prueba cambios de regla) |
