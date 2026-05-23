import * as THREE from "three";

/**
 * Creates a simple satellite geometry - a box with extended solar panels
 * Optimized for instanced rendering
 */
export function createSatelliteGeometry(): THREE.BufferGeometry {
  const geometry = new THREE.BufferGeometry();
  
  // Create satellite body as a simple rectangular box
  const bodyGeometry = new THREE.BoxGeometry(8, 8, 12);
  
  // Merge with solar panel geometries
  const panel1Geometry = new THREE.BoxGeometry(40, 25, 2);
  const panel2Geometry = new THREE.BoxGeometry(40, 25, 2);
  
  const vertices: number[] = [];
  const colors: number[] = [];
  const indices: number[] = [];
  let vertexCount = 0;
  
  // Helper to add box geometry
  function addBox(boxGeom: THREE.BoxGeometry, posX: number, posY: number, posZ: number, colorR: number, colorG: number, colorB: number) {
    const pos = boxGeom.getAttribute("position") as THREE.BufferAttribute;
    const idx = boxGeom.getIndex() as THREE.BufferAttribute;
    
    const startVertex = vertexCount;
    
    for (let i = 0; i < pos.count; i++) {
      vertices.push(
        pos.getX(i) + posX,
        pos.getY(i) + posY,
        pos.getZ(i) + posZ
      );
      colors.push(colorR, colorG, colorB);
    }
    
    if (idx) {
      for (let i = 0; i < idx.count; i++) {
        indices.push(idx.getX(i) + startVertex);
      }
    }
    
    vertexCount += pos.count;
  }
  
  // Body (light gray)
  addBox(bodyGeometry, 0, 0, 0, 0.8, 0.8, 0.85);
  
  // Solar panel 1 (blue)
  addBox(panel1Geometry, 25, 0, 0, 0.1, 0.3, 0.8);
  
  // Solar panel 2 (blue)
  addBox(panel2Geometry, -25, 0, 0, 0.1, 0.3, 0.8);
  
  // Set attributes
  geometry.setAttribute("position", new THREE.BufferAttribute(new Float32Array(vertices), 3));
  geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(colors), 3));
  geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(indices), 1));
  
  // Compute normals for lighting
  geometry.computeVertexNormals();
  
  return geometry;
}
