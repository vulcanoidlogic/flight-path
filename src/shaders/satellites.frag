varying vec3 vColor;
varying vec3 vNormal;
varying float vVisible;

void main() {
  if(vVisible < 0.5) {
    discard;
  }

  vec3 normal = normalize(vNormal);
  
  // High-altitude solar lighting orientation vector
  vec3 sunDirection = normalize(vec3(1.0, 1.25, 0.8));
  
  // Calculate standard Lambert diffuse shadowing
  float diffuseFactor = max(dot(normal, sunDirection), 0.0);
  
  // Baseline ambient value prevents shaded component faces from rendering completely pitch black
  float ambientFactor = 0.3;
  
  vec3 finalIllumination = vColor * (ambientFactor + (1.0 - ambientFactor) * diffuseFactor);
  
  gl_FragColor = vec4(clamp(finalIllumination, 0.0, 1.0), 1.0);
}