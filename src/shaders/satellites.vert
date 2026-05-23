// Per-instance curve control points (packed)
attribute vec4 controlPointsPack1; // (p0.x, p0.y, p0.z, p1.x)
attribute vec4 controlPointsPack2; // (p1.y, p1.z, p2.x, p2.y)
attribute vec4 controlPointsPack3; // (p2.z, p3.x, p3.y, p3.z)

// Per-instance rendering attributes
attribute vec3 instanceColor;
attribute float instanceScale;
attribute float instanceElevation;
attribute vec4 animationParams; // (phase, speed, rotation, visible)

// NOTE: Do NOT declare position, color, normal, projectionMatrix, 
// modelViewMatrix, or normalMatrix here. Three.js injects them automatically!

// Varyings
varying vec3 vColor;
varying vec3 vNormal;
varying float vVisible;

vec3 getControlPoint(int index) {
  if(index == 0) return vec3(controlPointsPack1.x, controlPointsPack1.y, controlPointsPack1.z);
  if(index == 1) return vec3(controlPointsPack1.w, controlPointsPack2.x, controlPointsPack2.y);
  if(index == 2) return vec3(controlPointsPack2.z, controlPointsPack2.w, controlPointsPack3.x);
  return vec3(controlPointsPack3.y, controlPointsPack3.z, controlPointsPack3.w);
}

vec3 evaluateCatmullRomSegment(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t, out vec3 tangent) {
  const float EPS = 1e-4;
  float dt0 = pow(max(dot(p1 - p0, p1 - p0), 0.0), 0.25);
  float dt1 = pow(max(dot(p2 - p1, p2 - p1), 0.0), 0.25);
  float dt2 = pow(max(dot(p3 - p2, p3 - p2), 0.0), 0.25);

  if(dt1 < EPS) dt1 = 1.0;
  if(dt0 < EPS) dt0 = dt1;
  if(dt2 < EPS) dt2 = dt1;

  vec3 m1 = (p1 - p0) / dt0 - (p2 - p0) / (dt0 + dt1) + (p2 - p1) / dt1;
  vec3 m2 = (p2 - p1) / dt1 - (p3 - p1) / (dt1 + dt2) + (p3 - p2) / dt2;
  m1 *= dt1; m2 *= dt1;

  vec3 c0 = p1; vec3 c1 = m1; vec3 c2 = -3.0 * p1 + 3.0 * p2 - 2.0 * m1 - m2; vec3 c3 = 2.0 * p1 - 2.0 * p2 + m1 + m2;
  float t2 = t * t; float t3 = t2 * t;

  vec3 rawTangent = c1 + 2.0 * c2 * t + 3.0 * c3 * t2;
  tangent = normalize(rawTangent);
  return c0 + c1 * t + c2 * t2 + c3 * t3;
}

vec3 evaluateCatmullRom(float t, out vec3 tangent) {
  vec3 p0 = getControlPoint(0); vec3 p1 = getControlPoint(1); vec3 p2 = getControlPoint(2); vec3 p3 = getControlPoint(3);
  if(t < 0.333) return evaluateCatmullRomSegment(p0 + (p0 - p1), p0, p1, p2, t / 0.333, tangent);
  if(t < 0.666) return evaluateCatmullRomSegment(p0, p1, p2, p3, (t - 0.333) / 0.333, tangent);
  return evaluateCatmullRomSegment(p1, p2, p3, p3 + (p3 - p2), (t - 0.666) / 0.334, tangent);
}

mat4 createOrientationMatrix(vec3 forward) {
  vec3 normalizedForward = normalize(forward);
  vec3 referenceUp = vec3(0.0, 1.0, 0.0);
  vec3 right = normalize(cross(referenceUp, normalizedForward));
  if(length(right) < 1e-5) {
    referenceUp = abs(normalizedForward.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    right = normalize(cross(referenceUp, normalizedForward));
  }
  vec3 newUp = normalize(cross(normalizedForward, right));
  return mat4(
    right.x, right.y, right.z, 0.0,
    newUp.x, newUp.y, newUp.z, 0.0,
    normalizedForward.x, normalizedForward.y, normalizedForward.z, 0.0,
    0.0, 0.0, 0.0, 1.0
  );
}

mat4 rotateAroundAxis(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle); float c = cos(angle); float oc = 1.0 - c;
  return mat4(
    oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
    oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
    oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
    0.0,                                 0.0,                                 0.0,                                  1.0
  );
}

void main() {
  // Blend geometry part colors (from our custom SatelliteGeometry buffer) with instance status colors
  vColor = color * instanceColor;

  float phase = animationParams.x;
  float speed = animationParams.y;
  float rotationRate = animationParams.z;
  float visible = animationParams.w;

  if(visible < 0.5 || paneVisibility < 0.5) {
    vVisible = 0.0;
    gl_Position = vec4(0.0, 0.0, 0.0, 0.0);
    return;
  }
  vVisible = 1.0;

  float animTime = time * speed + phase;
  float cycle = mod(animTime, returnMode > 0.5 ? 2.0 : 1.0);
  float travelDirection = 1.0;
  float t = cycle;
  
  if(returnMode > 0.5 && cycle > 1.0) {
    travelDirection = -1.0;
    t = 2.0 - cycle;
  }

  vec3 tangent;
  vec3 curvePosition = evaluateCatmullRom(t, tangent);
  tangent *= travelDirection;

  vec3 surfaceNormal = normalize(curvePosition);
  curvePosition += surfaceNormal * instanceElevation;

  mat4 rotationMatrix = createOrientationMatrix(tangent);
  float selfRotation = rotationRate * time;
  mat4 selfRotationMatrix = rotateAroundAxis(vec3(0.0, 0.0, 1.0), selfRotation);
  
  mat4 combinedRotation = rotationMatrix * selfRotationMatrix;

  // Transform vertex normal using our custom instance-space orientation changes
  vNormal = normalMatrix * (mat3(combinedRotation) * normal);

  vec3 scaledPosition = position * instanceScale;
  vec4 worldPosition = vec4(curvePosition, 1.0) + combinedRotation * vec4(scaledPosition, 1.0);

  gl_Position = projectionMatrix * modelViewMatrix * worldPosition;
}