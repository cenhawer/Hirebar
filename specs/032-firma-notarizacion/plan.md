# Implementation Plan: Firma de la app

**Branch**: `feature/HB-032-firma-notarizacion` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

- Sin cambios de código: `scripts/bundle.sh` ya firma con `HIREBAR_SIGN_IDENTITY` (ad-hoc por
  defecto, o el certificado Apple Development del usuario).
- README: nota explícita sobre la limitación de Gatekeeper sin Developer ID de pago, y el paso
  manual para abrir la app igual en otra Mac.

## Constitution Check

| Principio | Cumple | Cómo |
|---|---|---|
| Sin dependencias externas de distribución | ✅ | Firma local con las herramientas de Xcode, sin servicios de terceros |
| Documentación honesta de limitaciones | ✅ | README explica la limitación en vez de prometer notarización inexistente |
