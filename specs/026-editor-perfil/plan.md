# Implementation Plan: Editor de perfil

**Branch**: `feature/HB-026-editor-perfil` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

- Dominio: `ProfileDocument` (`PersonDetails`, `JobPreferences`, `WorkExperience` con `Achievement`,
  `CVVariantEntry`) y `problems` con `ProfileProblem`. Cada elemento recuerda su posición original
  (`source`) para conservar sus campos extra al guardar.
- Aplicación: `ProfileRepository.document()` y `saveDocument(_:)`; `ProfileProblem.message` con los
  textos para la persona.
- Storage: `ProfileDocumentStore` lee y fusiona sobre el JSON original, estampa `schemaVersion` y no
  escribe sobre un archivo más nuevo.
- App: Ajustes → Perfil → Datos y experiencia (`ProfileEditorView`, `ExperienceSection`,
  `ResumeVariantsSection`); al guardar, un problema lleva a esa página con su mensaje.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| VII. Probado sin red ni IA | ✅ | Validación y almacén con tests sin interfaz |
| VIII. Arquitectura hexagonal | ✅ | Ajustes usa el puerto `ProfileRepository` |
| Datos versionados | ✅ | `schemaVersion` y protección de versiones más nuevas |
