// Per-instance curve control points (packed)
attribute vec4 controlPointsPack1; // (p0.x, p0.y, p0.z, p1.x)
attribute vec4 controlPointsPack2; // (p1.y, p1.z, p2.x, p2.y)
attribute vec4 controlPointsPack3; // (p2.z, p3.x, p3.y, p3.z)

// Per-instance rendering attributes
attribute vec3 instanceColor;
attribute float instanceScale;
attribute float instanceElevation;
attribute vec4 animationParams; // (phase, speed, tiltMode, visible)

// Uniforms
uniform float time;
uniform float returnMode;
uniform float paneVisibility;

// Varyings sent to fragment shader
varying vec3 vColor;
varying vec3 vNormal;
varying float vVisible;

// Unpack control points from packed attributes (MUST BE FIRST)
vec3 getControlPoint(int index) {
  if(index == 0) {
    return vec3(controlPointsPack1.x, controlPointsPack1.y, controlPointsPack1.z);
  } else if(index == 1) {
    return vec3(controlPointsPack1.w, controlPointsPack2.x, controlPointsPack2.y);
  } else if(index == 2) {
    return vec3(controlPointsPack2.z, controlPointsPack2.w, controlPointsPack3.x);
  } else {
    return vec3(controlPointsPack3.y, controlPointsPack3.z, controlPointsPack3.w);
  }
}

// CatmullRom curve evaluation for a single segment
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
  float tangentLength = max(length(rawTangent), 1e-6);
  tangent = rawTangent / tangentLength;

  return c0 + c1 * t + c2 * t2 + c3 * t3;
}

// Evaluate CatmullRom spline through all 4 control points
vec3 evaluateCatmullRom(float t, out vec3 tangent) {
  vec3 p0 = getControlPoint(0); vec3 p1 = getControlPoint(1); vec3 p2 = getControlPoint(2); vec3 p3 = getControlPoint(3);

  vec3 positionResult;

  if(t < 0.333) {
    float localT = t / 0.333;
    vec3 p_before = p0 + (p0 - p1);
    positionResult = evaluateCatmullRomSegment(p_before, p0, p1, p2, localT, tangent);
  } else if(t < 0.666) {
    float localT = (t - 0.333) / 0.333;
    positionResult = evaluateCatmullRomSegment(p0, p1, p2, p3, localT, tangent);
  } else {
    float localT = (t - 0.666) / 0.334;
    vec3 p_after = p3 + (p3 - p2);
    positionResult = evaluateCatmullRomSegment(p1, p2, p3, p_after, localT, tangent);
  }

  return positionResult;
}

// Create orientation matrix to orient model along curve path
mat4 createOrientationMatrix(vec3 forward, vec3 upReference, float tiltMode, vec3 surfaceNormal) {
  vec3 normalizedForward = normalize(forward);
  vec3 referenceUp = upReference;

  vec3 right = normalize(cross(referenceUp, normalizedForward));
  if(length(right) < 1e-5) {
    referenceUp = abs(normalizedForward.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    right = normalize(cross(referenceUp, normalizedForward));
  }

  vec3 newUp = normalize(cross(normalizedForward, right));

  mat4 rotationMatrix;

  if(tiltMode < 0.5) {
    // Perpendicular mode: align forward
    rotationMatrix = mat4(
      right.x, right.y, right.z, 0.0,
      newUp.x, newUp.y, newUp.z, 0.0,
      normalizedForward.x, normalizedForward.y, normalizedForward.z, 0.0,
      0.0, 0.0, 0.0, 1.0
    );
  } else {
    // Tangent mode: align parallel to the Earth's surface curvature
    vec3 normalVec = normalize(surfaceNormal);
    if(length(normalVec) < 1e-5) normalVec = vec3(0.0, 1.0, 0.0);

    vec3 tangentDir = normalize(normalizedForward);
    if(length(tangentDir) < 1e-5) tangentDir = vec3(1.0, 0.0, 0.0);

    vec3 binormal = normalize(cross(normalVec, tangentDir));
    if(length(binormal) < 1e-5) {
      binormal = normalize(cross(vec3(0.0, 1.0, 0.0), normalVec));
      if(length(binormal) < 1e-5) binormal = vec3(1.0, 0.0, 0.0);
    }
    tangentDir = normalize(cross(binormal, normalVec));

    rotationMatrix = mat4(
      binormal.x, binormal.y, binormal.z, 0.0,
      tangentDir.x, tangentDir.y, tangentDir.z, 0.0,
      normalVec.x, normalVec.y, normalVec.z, 0.0,
      0.0, 0.0, 0.0, 1.0
    );
  }

  return rotationMatrix;
}

void main() {
  // Multiply sub-geometry array colors (solar panels/bus) by the tracking status highlight
  vColor = color * instanceColor;

  float phase = animationParams.x;
  float speed = animationParams.y;
  float tiltMode = animationParams.z;
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

  float t;
  if(returnMode > 0.5) {
    if(cycle > 1.0) {
      travelDirection = -1.0;
      t = 2.0 - cycle;
    } else {
      t = cycle;
    }
  } else {
    t = cycle;
  }

  vec3 tangent;
  vec3 curvePosition = evaluateCatmullRom(t, tangent);
  tangent *= travelDirection;

  vec3 upReference = vec3(0.0, 1.0, 0.0);
  vec3 surfaceNormal = normalize(curvePosition);
  curvePosition += surfaceNormal * instanceElevation;

  mat4 rotationMatrix = createOrientationMatrix(tangent, upReference, tiltMode, surfaceNormal);

  // Compute normal mapping transformed by the instance's 3D spatial rotation
  vNormal = normalMatrix * (mat3(rotationMatrix) * normal);

  // Apply scale directly to local component geometry
  vec3 localScaledPos = position * instanceScale;

  // Transform model vertices into world position tracking vectors
  vec4 worldPosition = vec4(curvePosition, 1.0) + rotationMatrix * vec4(localScaledPos, 0.0);

  gl_Position = projectionMatrix * modelViewMatrix * worldPosition;
}