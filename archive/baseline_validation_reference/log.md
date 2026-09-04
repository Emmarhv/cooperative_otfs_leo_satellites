> **CLOSURE NOTE (added 2026-08-28, does not modify anything below).**
> This document is preserved as HISTORICAL evidence. Fase 7, the load
> trade-off study, the final comparison, reporting, and
> `fase7_propuesta/official/` are all now CLOSED/FROZEN. For the
> current, canonical, thesis-ready synthesis, see
> `docs/thesis_support/00_MASTER_INDEX.md` and the documents it points
> to. Any statement below implying an open question that is not also
> listed as open in `docs/thesis_support/` has been resolved -- check
> the canonical layer before treating it as still pending.

---

# Fase 6 -- Baseline (compensacion geometrica + precoder Doppler P7)

## Fecha
Abierta 2026-08-08. Ultima actualizacion 2026-08-12 (sesion larga:
ruido, arquitectura de receptor, truncamiento). Fase todavia NO
cerrada.

## Objetivo de esta fase

Integrar la geometria real de la constelacion, el link budget, y el
precoder Doppler ya validado (Fase 5), para producir la curva BER
real del baseline -- este es el resultado que se compara contra la
Fase 7 (propuesta N1!=N2).

---

## Bloque 1 -- Modelado del ruido (cerrado, validado)

- `utils/add_branch_noise.m` (nuevo): ruido por rama,
  `y_j=sqrt(gamma_j)*s_j+w_j`. 6/6 tests aislados PASS.
- `receiver/mrc_combine.m` (nuevo, generalizado despues con fase):
  combinador por ramas, pesos `sqrt(gamma_j)`. Generalizado con
  `phi1, phi2` opcionales (default 0) tras comprobar que ignorar la
  fase entre ramas rompe la combinacion (SNR 0.65 vs 12.00
  esperado) y que pasarla correctamente la recupera (11.98 vs
  12.00).
- `metrics/compute_combined_snr.m` (nuevo): referencia teorica ideal
  gamma1+gamma2.
- `metrics/compute_truncation_sinr.m` (nuevo): ecs. (18)-(19) del
  paper del precoder, en notacion original (h1,h2,NR,PT por
  separado, no reparametrizada en gamma).

## Bloque 2 -- Decision de arquitectura del receptor (cerrado)

Se compararon dos arquitecturas, ambas matematicamente validas y
equivalentes por Monte Carlo (misma BER en multiples pares de
gamma):

- **Por ramas** (estilo paper del precoder): cada satelite demodula
  por separado, se realinea, se combina con `mrc_combine.m`.
  Necesita conocer la fase del canal efectivo si no es cero.
- **Suma ponderada** (estilo paper del baseline, ec. 12): las dos
  ramas se suman en tiempo ponderadas por `gamma_j` directamente, un
  unico ruido `CN(0,gamma1+gamma2)`, un unico demodulador OTFS.
  NUNCA hace falta separar h_j de gamma_j.
yo esto no lo he comrpobado en ningun momento, supuestamente lo ha hehco la IA no me fio

**Elegida como oficial: suma ponderada.** Motivo completo en
docs/decisiones.md, entrada 2026-08-12.

Archivos nuevos:
- `compensation/apply_precoder_blocks.m` -- aplica `B^q` con la
  permutacion de retardo ya resuelta en el transmisor (reformulacion
  propia, no literal de ningun paper). Validado:
  - `test_apply_precoder_blocks.m`: 5 escenarios, error ~1e-15, sin
    circshift en recepcion.
  - `test_apply_precoder_blocks_vs_Heff.m`: adjunto exacto de
    `H_eff` construido de forma independiente (canal fisico real
    aplicado a cada vector base), error ~1e-16, 3 escenarios.
- `receiver/combine_weighted_links.m` -- `gamma1*r1+gamma2*r2`.

La arquitectura por ramas (`add_branch_noise.m` + `mrc_combine.m`)
**no se elimina** -- se conserva como puente de validacion hacia la
propuesta N1!=N2.

## Bloque 3 -- Truncamiento del precoder (cerrado, validado)

- **Convencion resuelta: `2P+1`** (no `2P+2`, que se implemento
  primero por error). `build_precoder_blocks_adapted.m` y
  `simulation_parameters('baseline').precoderTruncationOrder=3`
  actualizados.
- **`metrics/compute_residual_interference.m`** (nuevo): mide
  `r = y_clean - G*x`, el residuo que deja un precoder truncado
  frente al canal completo, sin ruido. No lo genera artificialmente
  -- solo lo mide.
- **Resultado principal, escenario de referencia (M=1024, N=32,
  ieff=504, keff=-2, kappaeff=0.236, P=3):**
  - Energia Doppler retenida: 97.47%% (removida: 2.53%%).
  - Residuo relativo frente al canal completo, solo teniendo en cuenta  sat 2: 16.2%%.
  - Perdida de potencia TX medida: 2.66%% (coincide con la energia
    de coeficientes retenida).
  - Con precoder completo (sin truncar): residuo ~1e-15 (numerico).
- **Comportamiento confirmado, no asumido:**
  - El residuo decrece monotonamente segun crece P (medido con el
    operador completo: los 2 P vectores base de una rejilla
    pequena, no una sola trama aleatoria).
  - Con Doppler entero (kappa=0) y P=0, el residuo es
    numericamente cero -- toda la energia Doppler esta en un unico
    coeficiente, la truncacion no pierde nada.
  - El modelo de recepcion pasa de `x_hat=G*x+v` (precoder
    completo) a `x_hat=G*x+r+v` (precoder truncado).
- Coeficientes de Dirichlet verificados contra una forma analitica
  independiente (seno/exponencial, distinta de la implementada) a
  ~1e-15 en todos los escenarios, incluida la escala de referencia.

## Bloque 4 -- Limpieza de configuracion (cerrado)

`config/reference_ber_parameters.m` reescrito: ya no duplica
parametros fisicos (EIRP, temperatura, rangos, residuos) que ya
estaban en `channel_scenario.m` -- se detecto una desincronizacion
real (`cpLength` distinto entre `simulation_parameters.m` y lo que
un test antiguo esperaba) causada exactamente por esta duplicacion.
`channel_scenario.m` es ahora la unica fuente de parametros fisicos.
`compute_link_snr.m` no necesito cambios (ya era generico).

## Bloque 5 -- Auditoria de tests (cerrado)

Revision completa de los ~20 tests nuevos de esta fase buscando
verificaciones circulares (el valor "esperado" derivado de la misma
pieza que se prueba). Encontrados y corregidos 2 casos reales --
detalle completo en docs/decisiones.md, entrada 2026-08-12. Tambien
se encontro y corrigio `tests/fase5_precoder_doppler/test_precoder_truncation.m`,
que fallaba por seguir escrito para la convencion `2P+2` abandonada.

## Bloque 6 -- Reorganizacion de tests (cerrado)

`tests/fase6_baseline/` reorganizada en subcarpetas numeradas por
capa (ver `tests/fase6_baseline/README.md`):

```
00_geometry_link_budget/       (pausada, sin tocar)
01_noise_isolated_functions/   (funciones sueltas, deterministas)
02_noise_combined_statistics/  (ruido+combinacion, sin QAM/BER)
03_noise_ber_integration/      (con QAM real, BER como metrica)
04_full_pipeline/              (precoder+canal+ruido+demod+BER)
05_truncation/                 (residuo por truncamiento)
```
30 ficheros de test en total entre esta carpeta y
`tests/fase5_precoder_doppler/` (renombrada, sin "p7" en el nombre).
Todos en PASS tras la reorganizacion (verificado, no solo asumido).

---

## Que falta -- bloqueante, en orden

1. **Geometria y link budget reales** siguen pausados por decision
   explicita durante toda la sesion -- los tests de
   `00_geometry_link_budget/` pasan (usan `channel_scenario.m` +
   valores publicados de referencia), pero no se ha tocado nada de
   esa zona mas alla de la limpieza de duplicados del Bloque 4.
2. **Ensamblar `main/main_baseline.m`** (sigue vacio, 0 bytes)
   conectando: geometria/link budget + `apply_precoder_blocks.m` +
   `combine_weighted_links.m` + `add_normalized_complex_noise.m` +
   un unico `otfs_demodulate` -- la arquitectura oficial ya validada
   pieza por pieza (Bloques 1-3) y de extremo a extremo en tests
   (`test_reference_link_budget_pipeline.m`,
   `test_reference_truncation_diagnostics.m`), pero nunca ensamblada
   como script de produccion.
3. **Decidir si el baseline final usa el precoder completo o
   truncado (P=3)** -- ambos estan implementados y validados; falta
   la decision de cual usar para la curva BER final, y si hace falta
   renormalizar la perdida de potencia (2.66%%) del caso truncado.
4. **Ejecutar la simulacion Monte Carlo real a escala de produccion
   y generar la curva BER** -- esto es lo que cierra la fase.

## Criterio de validacion de esta fase
Mejora respecto a Fase 4 (suelo de BER ~0.193 QPSK / ~0.307 16-QAM
sin compensacion), reproduciendo razonablemente la curva BER
publicada por el paper del baseline en su Fig. 3/5-6.

## Se cumple el criterio?
- [ ] Si
- [ ] No / parcialmente
- [x] Pendiente -- todas las piezas (geometria, precoder, ruido,
  arquitectura de receptor, truncamiento) estan implementadas y
  validadas por separado y en integraciones parciales, pero el
  `main_baseline.m` que las une en un unico script de produccion
  todavia no existe.

## Dudas / cosas raras encontradas
- La SINR truncada no es monotona en P para valores pequenos de P
  (baja en P=1 antes de recuperarse) -- propiedad real del nucleo de
  Dirichlet, no un bug. Ver Fase 5, `test_precoder_truncation.m`.
- Discrepancia de convencion `2P+1` (paper del baseline) vs `2P+2`
  (implementacion inicial, error de lectura, ya corregida) --
  documentado en docs/decisiones.md para que no se repita si se
  revisa la ruta P13/H_eff archivada en el futuro.

## Proximo paso
Ver checklist "Que falta" arriba, punto 1 (retomar geometria/link
budget) o punto 2 (ensamblar main_baseline.m con los valores
validationReference como atajo, si se prefiere no esperar a la
geometria real).

---

## Baseline BER without reconstructed geometry

### Fecha
2026-08-13.

### Objetivo
Comprobar que toda la cadena de comunicaciones construida hasta ahora
(QAM, OTFS, precoder Doppler P7 truncado P=3, canal residual, receptor
de suma ponderada, ruido combinado, demodulacion, deteccion, BER) es
capaz de reproducir aproximadamente la curva BER publicada, usando
directamente el snapshot publicado (rangos y offsets efectivos) en
lugar de la geometria fisica reconstruida.

### Archivo
`main/main_baseline_no_geom.m` (nuevo). No reconstruye geometria: usa
`scenario.validationReference.ieff/qeff/kappaeff` y
`scenario.satellites(1:2).slantRange` directamente desde
`channel_scenario.m`.

### Configuracion
- OTFS: M=1024, N=32, DeltaF=240 kHz, bandwidth=245.76 MHz
- Offsets: ieff=504, keff=-2, kappaeff=0.236
- Precoder: P=3, 2P+1=7 coeficientes activos, sin renormalizacion de
  potencia (TX-power renormalization = OFF)
- CP: cpLength de simulacion = 0; CP fisico de referencia = M-1 = 1023
- Slant ranges publicados: satelite 1 = 588.08 km, satelite 2 = 657.97 km
- Barrido N_R: arraySideVec = 8:2:24 -> N_R = arraySideVec.^2 =
  {64,100,144,196,256,324,400,484,576}, eje 10*log10(N_R)
- Modulaciones: QPSK, 16-QAM

### Arquitectura utilizada
La misma ya validada en Bloques 1-3 (suma ponderada, un unico ruido
combinado CN(0,gamma1+gamma2), un unico demodulador OTFS). No se usa
`compute_physical_links.m`, `compute_effective_offsets.m`, MRC por
ramas, `add_branch_noise.m`, OFDM, spectral efficiency ni la propuesta
N1!=N2.

### Diagnostico del link budget
N_R=64: gamma1=5.389 dB, gamma2=4.413 dB.
N_R=576: gamma1=14.931 dB, gamma2=13.956 dB.
Referencia publicada: satelite 1 aprox. 5.41 -> 14.95 dB, satelite 2
aprox. 4.43 -> 13.97 dB. Coincidencia practica (diferencias < 0.03 dB
en todos los puntos extremos).

### Truncacion P=3 (diagnostico, N_R=64)
- active coefficients = 7
- retained coefficient energy (analitica, sobre cvec) = 0.97470056
- measured precoder TX power ratio (sobre una trama concreta) =
  0.97584013
- relative clean residual = 6.993378e-02
- residual power before receiver normalization = 1.892768e-01
- residual power after receiver normalization = 4.890734e-03

La diferencia entre 0.97470056 y 0.97584013 NO se interpreta como
error: la primera es la energia analitica de los coeficientes
retenidos, la segunda es una medida sobre una realizacion de senal
concreta. La perdida de potencia del precoder truncado NO se ha
renormalizado.

### Resultados BER QPSK

| N_R | N_R (dB) | BER | errors | bits | stop |
|---|---|---|---|---|---|
| 64 | 18.06 | 7.706e-03 | 505 | 65536 | minErrors |
| 100 | 20.00 | 1.205e-03 | 237 | 196608 | minErrors |
| 144 | 21.58 | 1.789e-04 | 211 | 1179648 | minErrors |
| 196 | 22.92 | 1.734e-05 | 200 | 11534336 | minErrors |
| 256 | 24.08 | 1.400e-06 | 28 | 20000000 | maxBits |
| 324 | 25.11 | 1.000e-07 | 2 | 20000000 | maxBits |
| 400 | 26.02 | 5.000e-08 | 1 | 20000000 | maxBits |
| 484 | 26.85 | 0 (sin errores) | 0 | 20000000 | maxBits |
| 576 | 27.60 | 0 (sin errores) | 0 | 20000000 | maxBits |

### Resultados BER 16-QAM

| N_R | BER |
|---|---|
| 64 | 1.047e-01 |
| 100 | 6.672e-02 |
| 144 | 4.070e-02 |
| 196 | 2.408e-02 |
| 256 | 1.443e-02 |
| 324 | 8.171e-03 |
| 400 | 4.219e-03 |
| 484 | 2.571e-03 |
| 576 | 1.236e-03 |

### Comparacion con el articulo
No se afirma coincidencia numerica exacta punto a punto: el articulo
no publica los valores BER originales de cada punto, solo la Fig. 6.
Se distingue explicitamente:
- coincidencia numerica exacta -> NO demostrable
- concordancia aproximada -> SI
- reproduccion satisfactoria del comportamiento publicado -> SI

La BER disminuye correctamente al aumentar N_R; QPSK presenta menor
BER que 16-QAM en todo el barrido; el link budget coincide en la
practica con el publicado; no aparece un error floor visible en el
rango estudiado (16-QAM sigue bajando monotonamente hasta el ultimo
punto simulado), consistente con la afirmacion del articulo de que el
residuo de truncacion no genera un error floor apreciable en el rango
evaluado.

### Conclusion
El baseline OTFS dual se considera reproducido satisfactoriamente. Las
curvas simuladas para QPSK y 16-QAM presentan una concordancia
estrecha con la Fig. 6 del articulo de referencia, tanto en tendencia
como en orden de magnitud y posicion aproximada de los puntos. No
puede afirmarse igualdad numerica exacta punto a punto porque el
articulo no proporciona los valores BER originales, unicamente su
representacion grafica.

### Limitaciones actuales
- `iEff`, `kEff`, `kappaEff` y los slant ranges se toman directamente
  del snapshot publicado (`scenario.validationReference`), NO se
  derivan todavia de geometria reconstruida.
- `main_baseline_no_geom.m` queda congelado como referencia de
  regresion (snapshot publicado). El futuro `main_baseline.m` debera
  reutilizar exactamente el mismo pipeline de comunicaciones, cambiando
  unicamente el origen de ranges/iEff/kEff/kappaEff (geometria fisica
  propia en vez del snapshot).
- Auditoria READ-ONLY completa de `main_baseline_no_geom.m` y de
  `tests/fase6_baseline/04_full_pipeline/test_reference_baseline_snapshot_pipeline.m`
  realizada 2026-08-13: sin errores reales encontrados. Detalle en la
  entrada correspondiente de `TFG_tracker.md` / `docs/decisiones.md`.
