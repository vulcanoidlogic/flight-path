varying vec3 vColor;
varying vec3 vNormal;
varying float vVisible;

void main() {
  if(vVisible < 0.5) {
    discard;
  }

  // Simple lighting using normal
  vec3 normal = normalize(vNormal);
  vec3 light = normalize(vec3(1.0, 1.0, 1.0));
  
  float diff = max(dot(normal, light), 0.0);
  vec3 result = vColor * (0.3 + 0.7 * diff);
  
  gl_FragColor = vec4(result, 1.0);
}
