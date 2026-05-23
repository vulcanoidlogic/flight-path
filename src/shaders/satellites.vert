// Per-instance curve control points (packed)
attribute vec4 controlPointsPack1;
attribute vec4 controlPointsPack2;
attribute vec4 controlPointsPack3;

// Per-instance rendering attributes
attribute vec3 instanceColor;
attribute float instanceScale;
attribute float instanceElevation;
attribute vec4 animationParams;

// Geometry per-vertex attributes
attribute vec3 color; // <-- ADD THIS EXPLICIT DECLARATION HERE

// Custom Uniforms
uniform float time;
uniform float returnMode;
uniform float paneVisibility;

// Varyings
varying vec3 vColor;
varying vec3 vNormal;
varying float vVisible;

// Clean segment evaluation returning position directly
vec3 evaluateSegmentPos(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
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
  return c0 + c1 * t + (c2 * t * t) + (c3 * t * t * t);
}

// Clean segment evaluation returning tangent directly
vec3 evaluateSegmentTangent(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
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

  vec3 c1 = m1; vec3 c2 = -3.0 * p1 + 3.0 * p2 - 2.0 * m1 - m2; vec3 c3 = 2.0 * p1 - 2.0 * p2 + m1 + m2;
  vec3 rawTangent = c1 + 2.0 * c2 * t + 3.0 * c3 * t * t;
  return normalize(rawTangent);
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

  // Explicit inline vector unpacking to completely avoid dynamic branch lookups
  vec3 p0 = vec3(controlPointsPack1.x, controlPointsPack1.y, controlPointsPack1.z);
  vec3 p1 = vec3(controlPointsPack1.w, controlPointsPack2.x, controlPointsPack2.y);
  vec3 p2 = vec3(controlPointsPack2.z, controlPointsPack2.w, controlPointsPack3.x);
  vec3 p3 = vec3(controlPointsPack3.y, controlPointsPack3.z, controlPointsPack3.w);

  vec3 curvePosition;
  vec3 tangent;

  // Evaluate curve paths safely without reference cross-contamination
  if(t < 0.333) {
    float localT = t / 0.333;
    curvePosition = evaluateSegmentPos(p0 + (p0 - p1), p0, p1, p2, localT);
    tangent = evaluateSegmentTangent(p0 + (p0 - p1), p0, p1, p2, localT);
  } else if(t < 0.666) {
    float localT = (t - 0.333) / 0.333;
    curvePosition = evaluateSegmentPos(p0, p1, p2, p3, localT);
    tangent = evaluateSegmentTangent(p0, p1, p2, p3, localT);
  } else {
    float localT = (t - 0.666) / 0.334;
    curvePosition = evaluateSegmentPos(p1, p2, p3, p3 + (p3 - p2), localT);
    tangent = evaluateSegmentTangent(p1, p2, p3, p3 + (p3 - p2), localT);
  }
  
  tangent *= travelDirection;

  vec3 surfaceNormal = normalize(curvePosition);
  curvePosition += surfaceNormal * instanceElevation;

  mat4 rotationMatrix = createOrientationMatrix(tangent);
  float selfRotation = rotationRate * time;
  mat4 selfRotationMatrix = rotateAroundAxis(vec3(0.0, 0.0, 1.0), selfRotation);
  
  mat4 combinedRotation = rotationMatrix * selfRotationMatrix;

  vNormal = normalMatrix * (mat3(combinedRotation) * normal);

  // Safely assign attribute position data to local coordinates 
  vec3 localPositionCopy = position * instanceScale;
  vec4 worldPosition = vec4(curvePosition, 1.0) + combinedRotation * vec4(localPositionCopy, 1.0);

  gl_Position = projectionMatrix * modelViewMatrix * worldPosition;
}