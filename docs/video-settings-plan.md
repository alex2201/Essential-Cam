# Configuraciones y presets de Foto/Video

## Alcance acordado

Los ajustes de Foto y Video se conservan independientemente en memoria durante
la sesión. Al cambiar de modo se aplican sus valores. No se persisten los valores
activos, el último modo, ni el preset seleccionado al relanzar.

Se persisten únicamente:

- Presets, diferenciados por modo, en el repositorio JSON local existente.
- Selección y orden de controles rápidos, con claves independientes por modo.

## Entregas de implementación

1. Modelar ajustes de video y perfiles independientes sin conectar CameraSettingsStore.
2. Preparar la sesión para el modo/formato activo antes de grabar, con rollback.
3. Reutilizar exposición, enfoque y balance de blancos con capacidades actualizadas.
4. Habilitar Settings desde Video e incorporar resolución y fps compatibles.
5. Añadir H.264/HEVC, estabilización y luz continua cuando estén disponibles.
6. Diferenciar presets y completar los campos de Foto y Video.
7. Separar personalización de controles rápidos y validar en portrait/texto grande.

## Configuraciones

- Video: 1080p/4K, 24/25/30/50/60 fps, H.264/HEVC, estabilización y luz continua,
  filtrados por dispositivo/formato. Contenedor MOV y color SDR.
- Controles compatibles en ambos modos: exposición automática/manual, compensación,
  ISO/obturación, enfoque automático/manual y balance de blancos automático/manual.
- Foto conserva aspecto, formatos de imagen, resolución, timer, corrección y flash.
- Zoom/lente/cámara siguen en la interfaz; los presets no incluyen zoom ni IDs de hardware.
- Configuraciones bloqueadas durante grabación, finalización y guardado.
- Opciones incompatibles se ajustan con un aviso sin modificar el preset guardado.

## Compatibilidad local

Los presets antiguos se decodifican como Foto. Los campos nuevos ausentes conservan
la semántica anterior. Se mantienen IDs, nombres y orden. Los archivos nuevos
usan esquema versionado; errores de lectura o versiones desconocidas impiden
sobrescribir el archivo anterior. El editor muestra errores de persistencia.

La personalización existente de controles rápidos sigue siendo de Foto. Video
usa una clave local independiente. Modificar un preset activo no actualiza el
preset guardado; guardar/editar es una operación explícita.

## Validación

Pruebas de separación de perfiles, migración, resolver de capacidades, guardado y
restauración de presets, selección/orden por modo y personalización independiente.
Pruebas de interfaz vertical y texto de accesibilidad grande. Build, instalación,
lanzamiento y pruebas de grabación/captura en iPhone Alex 14 Pro Max.

Mantener iOS 18.0 como mínimo. HDR, Log, ProRes, audio avanzado y cambios durante
la grabación quedan fuera de esta entrega y requieren evaluación independiente.

## Referencias

- [Apple: codecs de MovieFileOutput](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput/availablevideocodectypes).
- [Apple: duración de cuadros](https://developer.apple.com/documentation/avfoundation/avcapturedevice/activevideominframeduration).
- [Apple: espacios de color por formato](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/supportedcolorspaces).
