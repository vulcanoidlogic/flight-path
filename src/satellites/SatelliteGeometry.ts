import * as THREE from "three";

/**
 * Creates an SDA-resembling satellite geometry:
 * A low-profile rectangular bus body, wide solar panels, and 4 corner OISL laser payloads.
 * Optimized for high-performance instanced rendering.
 */
export function createSatelliteGeometry(): THREE.BufferGeometry {
  const geometry = new THREE.BufferGeometry();
  
  // 1. SDA Bus Body: Modern buses are flatter, wide, and compact
  const bodyGeometry = new THREE.BoxGeometry(10, 5, 12);
  
  // 2. Solar Arrays: Distinctly wide panel wings
  const panel1Geometry = new THREE.BoxGeometry(36, 12, 1);
  const panel2Geometry = new THREE.BoxGeometry(36, 12, 1);
  
  // 3. Optical Inter-Satellite Links (OISL): 4 small payloads for cross-linking
  const oislGeom = new THREE.BoxGeometry(2.5, 2.5, 3);
  
  const vertices: number[] = [];
  const colors: number[] = [];
  const indices: number[] = [];
  let vertexCount = 0;
  
  // Helper to add box geometries into the single buffer allocation
  function addBox(
    boxGeom: THREE.BoxGeometry, 
    posX: number, posY: number, posZ: number, 
    colorR: number, colorG: number, colorB: number
  ) {
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
  
  // --- Assemble Component Geometry ---
  
  // Main Satellite Chassis (Metallic Gold/Kapton Foil or Matte Silver)
  addBox(bodyGeometry, 0, 0, 0, 0.85, 0.75, 0.4); // Pale gold foil profile
  
  // Wide Solar Array - Starboard (Deep Blue/Black)
  addBox(panel1Geometry, 23, 0, 0, 0.05, 0.15, 0.4);
  
  // Wide Solar Array - Port (Deep Blue/Black)
  addBox(panel2Geometry, -23, 0, 0, 0.05, 0.15, 0.4);
  
  // 4x OISLs (Laser Communications) mounted on the forward/aft corners of the bus
  // Forward Starboard OISL (Glinting Steel/Cyan Sensor Lens look)
  addBox(oislGeom, 4, 2, 5, 0.3, 0.7, 0.9);
  // Forward Port OISL
  addBox(oislGeom, -4, 2, 5, 0.3, 0.7, 0.9);
  // Aft Starboard OISL
  addBox(oislGeom, 4, 2, -5, 0.3, 0.7, 0.9);
  // Aft Port OISL
  addBox(oislGeom, -4, 2, -5, 0.3, 0.7, 0.9);
  
  // --- Build Final Attribute Buffers ---
  geometry.setAttribute("position", new THREE.BufferAttribute(new Float32Array(vertices), 3));
  geometry.setAttribute("color", new THREE.BufferAttribute(new Float32Array(colors), 3));
  geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(indices), 1));
  
  // Regenerate normals so lighting works correctly with new face layouts
  geometry.computeVertexNormals();
  
  return geometry;
}