# Senderos del Horizonte 0.1.11

- Las laderas ocultan ahora objetos completamente tapados por el terreno,
  conservando vegetación, materiales, distancias, viento y sombras.
- El recurso se carga después de construir las grutas y verifica alturas,
  agujeros y regiones. Se retira si cambia el terreno.
- La preparación pesada queda horneada; el nuevo script no procesa cada
  fotograma.
- Comparación visual de exteriores e interiores, de día, noche y tormenta;
  pruebas de las cuatro grutas y combate cooperativo con procesos reales.

En las cámaras medidas del M2 Pro, a 1600×900 y sin VSync, el Tenebroso
pasa de **56,80 a 62,41 FPS** en movimiento, Puerto de **56,87 a 61,21**
y la villa de **69,96 a 74,19**. El bosque verde sigue en torno a 45 FPS.
Son mejoras de estas vistas; no son cifras medidas en Windows.

[Mediciones y límites de la optimización](OCLUSION_TERRENO.md).
El objetivo general de 100–120 FPS sigue pendiente. La web del NAS conserva
el ZIP completo con el ejecutable como descarga principal y el instalador
como alternativa.
