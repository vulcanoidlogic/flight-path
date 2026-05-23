varying vec3 vColor;
varying vec3 vNormal;
varying float vVisible;

void main() {
  if(vVisible < 0.5) {
    discard;
  }

  vec3 normal = normalize(vNormal);
  
  // Sun-like directional light coming slightly from above/side
  vec3 lightDirection = normalize(vec3(1.0, 1.5, 1.0));
  
  // Standard diffuse light calculation
  float diff = max(dot(normal, lightDirection), 0.0);
  
  // Ambient baseline light so unlit faces don't drop to pitch black
  float ambient = 0.25;
  
  vec3 finalColor = vColor * (ambient + (1.0 - ambient) * diff);
  
  gl_FragColor = vec4(finalColor, 1.0);
}