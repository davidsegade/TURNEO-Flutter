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
- Roster activo local por ID: `u1` (David, administrador), `u4` (Juan) y `u5`
  (Adrián); `u2` (Carlos) y `u3` (Alejandro) quedan fuera de la app, sin
  borrar sus históricos 2026. Aunque Supabase los mantenga activos para 2026,
  la app los rechaza por whitelist.
- El registro sólo ofrece `u5` Adrián y `u4` Juan, con `u5` seleccionado por
  defecto. `u5` usa `Santa Eufemia` como identidad Excel/Sheets.
- Login, recuperación, registro con la función existente y cierre de sesión.
- Edición del propio cuadrante; el administrador puede editar todos. Supabase aplica RLS.
- Actualización local de la celda guardada, sin cargar el histórico.
- Las escrituras de `planning` sólo se permiten en 2027. 2026 permanece
  disponible para lectura y sus históricos no se borran ni se reescriben.
- El destino de la auditoría/trigger de Google Sheets para 2027 es
  `1qL4Wrv9aR-LXlmRME4wMo2-GaVAp3y1jYeqEHT-6_0w`. Flutter no llama a Google
  Sheets directamente: escribe en Supabase y conserva el flujo Excel -> app y
  las fórmulas del libro. La configuración remota del trigger queda fuera de
  este cambio local.
- La migración Supabase 2027 de `app_users.sheet_name` y `u5` (`display_name =
  Adrián`, `sheet_name = Santa Eufemia`, `slot = 5`) ya fue aplicada y
  verificada. `u2/u3` pueden permanecer activos para la operación 2026 del
  backend, pero no entran en el roster ni en escrituras de la app.
- El endpoint remoto `shift-register` todavía sólo admite `u2/u3/u4`; el
  onboarding de `u5` requiere desplegar la versión corregida de esa Edge
  Function. Ese despliegue queda pendiente y no se realiza desde este repo.
- La sincronización automática app -> Google Sheets 2027 está en
  `tool/google_apps_script/turneo_2027_pull.gs`; requiere instalación y
  credenciales manuales. No se instala ni se ejecuta ningún trigger desde este
  repositorio.

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

Los balances se muestran desde `balance_snapshots`; Flutter no escribe ni
recalcula el histórico remoto. El cálculo puro común está en
`lib/src/data/balance_calculator.dart`: recibe los valores ya resueltos por
las reglas existentes, fija la baseline de DAS de `u5` en `0` y deja DF en
`null` si falta la resolución de cobertura de cualquier festivo.

El operador debe escribir una fila de `balance_baselines` por usuario y periodo
de cálculo, con `local_user_id`, el periodo completo (`period_id`, no solo el
mes) y `das_initial`; para `u5`, `das_initial = 0`. Debe escribir una fila de
`balance_snapshots` por usuario y periodo mostrado, con el mismo `period_id`,
`das_generated`, `das_available`, `df_available` y los campos PICO existentes.
Los periodos de ambas tablas deben ser idénticos y no deben mezclarse cierres
mensuales con periodos anuales.

`df_available` solo puede publicarse cuando el operador/backend haya resuelto
los festivos nacionales, autonómicos y locales del periodo y su disfrute según
el algoritmo existente, incluyendo turnos/coberturas cuando esa regla los
necesite. Si faltan esos datos, el resultado correcto en esta app es
desconocido, no cero ni una cifra estimada. Sheets y SQL se actualizan por sus
conectores separados; OpenCode no los modifica.

Las pruebas automatizadas cubren pantallas de 320 y 390 píxeles, edición sin
recarga, errores de guardado, permisos del cliente, consultas acotadas por mes,
cambio de año, contraste de MC/TC, baseline DAS de `u5` y la incertidumbre de
DF sin cobertura.
