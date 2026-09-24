# TURNEO Flutter

Nueva aplicación móvil TURNEO en Flutter, desarrollada en paralelo a la PWA existente.

Arquitectura conservada:

**Excel corporativo ⇄ Google Sheets ⇄ Supabase ⇄ TURNEO Flutter**

## Estado inicial

- Proyecto Flutter independiente.
- Supabase como backend existente.
- Pantalla General mensual.
- Lectura de `planning` por mes, no de todo el histórico.
- Colores leídos del catálogo `services`.
- Orden visual: Carlos, David, Alejandro, Juan.
- Primera fase en solo lectura para no alterar datos.

## Configuración

Las credenciales públicas de Supabase se inyectan al ejecutar/compilar:

```
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

No se guarda ninguna clave de servicio privilegiada en el repositorio.
