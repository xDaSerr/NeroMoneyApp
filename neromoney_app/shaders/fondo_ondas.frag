// Fondo de acceso con movimiento: la misma imagen de listones de vidrio,
// pero ondulando despacio a los lados y con un reflejo de luz que recorre los
// bordes de neón. El centro (donde van el texto y la tarjeta) casi no se
// mueve. Lo usa FondoAcceso (lib/features/auth/widgets/fondo_acceso.dart).
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;      // tamaño del área a pintar, en píxeles lógicos
uniform vec2 uImgSize;   // tamaño de la imagen decodificada, en píxeles
uniform float uTime;     // segundos desde que empezó la animación
uniform sampler2D uImagen;

out vec4 fragColor;

void main() {
  vec2 frag = FlutterFragCoord().xy;

  // Equivalente a BoxFit.cover: escala la imagen hasta cubrir el área y la
  // centra; lo que sobra se recorta.
  float escala = max(uSize.x / uImgSize.x, uSize.y / uImgSize.y);
  vec2 uv = ((frag - uSize * 0.5) / escala + uImgSize * 0.5) / uImgSize;

  // Un 2% de acercamiento para que el vaivén nunca deje ver el borde de la
  // imagen.
  uv = (uv - 0.5) * 0.98 + 0.5;

  // 0 en el centro, 1 en los lados: ahí están los listones.
  float lados = smoothstep(0.16, 0.40, abs(uv.x - 0.5));

  float t = uTime;
  // Dos ondas lentas superpuestas por eje, con periodos que no coinciden,
  // para que el movimiento no se sienta como un ciclo mecánico.
  float dx = sin(uv.y * 5.0 + t * 0.55) * 0.0065
           + sin(uv.y * 11.0 - t * 0.85) * 0.0025;
  float dy = sin(uv.x * 4.0 + t * 0.45) * 0.0090
           + cos(uv.x * 9.0 + t * 0.75) * 0.0030;
  uv += vec2(dx, dy) * lados;

  vec4 color = texture(uImagen, uv);

  // Reflejo: una franja diagonal que cruza la pantalla cada ~16 s y solo
  // aviva lo que ya brilla (los bordes de neón), no el fondo oscuro.
  float luz = dot(color.rgb, vec3(0.299, 0.587, 0.114));
  float posicion = fract(t / 16.0) * 2.6 - 0.8;
  float franja = exp(-pow((uv.x * 0.55 + uv.y * 0.45 - posicion) * 7.0, 2.0));
  float brillo = franja * smoothstep(0.22, 0.65, luz) * 0.55 * lados;

  // Respiración muy suave del brillo general de los listones.
  float respiracion = 1.0 + 0.05 * sin(t * 0.6) * lados;

  fragColor = vec4(color.rgb * respiracion + color.rgb * brillo, 1.0);
}
