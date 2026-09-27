# TURNEO Flutter

Nueva aplicación móvil TURNEO en Flutter, desarrollada en paralelo a la PWA existente.

Arquitectura conservada:

**Excel corporativo ⇄ Google Sheets ⇄ Supabase ⇄ TURNEO Flutter**

## Estado de la aplicación

- Proyecto Flutter independiente.
- Supabase como backend existente.
- Pantalla General mensual.
- Lectura de `planning` por mes, no de todo el histórico.
- Colores leídos del catálogo `services`.
- Orden visual: Carlos, David, Alejandro, Juan.
- Login, recuperación, registro con la función existente y cierre de sesión.
- Edición del propio cuadrante; el administrador puede editar todos. Supabase aplica RLS.
- Actualización local de la celda guardada, sin cargar el histórico.

## Configuración

Flutter 3.47.5 y Supabase Flutter 2.17.2. Los workflows validan la URL del
proyecto y el secreto `SUPABASE_PUBLISHABLE_KEY` contra Auth y REST. El mismo
archivo generado se utiliza al compilar, sin mezclar claves legacy:

```
python3 tool/check_config.py
flutter analyze
flutter test
flutter build web --release --base-href /TURNEO-Flutter/ --dart-define-from-file=build-config.json
```

El preflight recibe `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` por entorno.
`build-config.json` está excluido de Git. No se utiliza ninguna clave privilegiada
en el cliente. Las consultas anónimas no prueban el acceso autenticado:
las pruebas RLS y de sesión deben verificarse por separado.

Las pruebas automatizadas cubren pantallas de 320 y 390 píxeles, edición sin
recarga, errores de guardado, permisos del cliente, consultas acotadas por mes,
cambio de año y contraste de MC/TC. Los balances DAS/DF/PICO no se recalculan.
