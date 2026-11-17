# Implementation Plan: Textos y valores fuera del código

**Branch**: `feature/HB-024-string-catalog`, `feature/HB-024-valores` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

1. **String Catalog**: los textos para la persona pasan por `String(localized:)`; los de SwiftUI ya son
   `LocalizedStringKey`. Los textos largos usan literales de varias líneas con `\` al final de línea,
   así siguen siendo una sola clave. `scripts/strings.sh` compila con `-emit-localized-strings`, junta
   las claves en `Resources/Localizable.xcstrings` y con `--check` falla si no está al día; el CI lo
   corre y `bundle.sh` compila el catálogo con `xcstringstool`. `SourceShapeTests` vigila los puntos de
   salida.
2. **Valores**: palabras de búsqueda, descartes, plazos y tiempos de espera pasan a recursos JSON con
   versión, leídos en `HirebarStorage` y entregados a la aplicación.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Sin textos ni valores de dominio en el código | ✅ | Catálogo y recursos versionados |
| VII. Probado sin red ni IA | ✅ | Los tests leen el texto base del catálogo |
