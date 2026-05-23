import * as THREE from "three";
import vertexShader from "../shaders/satellites.vert?raw";
import fragmentShader from "../shaders/satellites.frag?raw";
import { createSatelliteGeometry } from "./SatelliteGeometry";
import type { PlanesShaderOptions } from "../common/Types.js";

/**
 * SatellitesShader - High-performance satellite renderer using instanced 3D geometry
 * Replaces 2D textured planes with realistic 3D satellite models
 */
export class SatellitesShader {
  private scene: THREE.Scene;
  private maxSatellites: number;
  private baseSize: number;
  private returnModeEnabled: boolean;
  private defaultElevation: number;

  // Instanced mesh components
  private instancedMesh: THREE.InstancedMesh | null = null;
  private geometry: THREE.BufferGeometry | null = null;
  private material: THREE.ShaderMaterial | null = null;

  // Per-instance data: curve control points (4 points for CatmullRom)
  private controlPointsPack1: Float32Array;
  private controlPointsPack2: Float32Array;
  private controlPointsPack3: Float32Array;

  // Per-instance colors and metadata
  private instanceColors: Float32Array;
  private instanceScales: Float32Array;
  private instanceElevations: Float32Array;
  private animationParams: Float32Array; // (phase, speed, rotationRate, visible)

  // Tracking
  private activeSatellites: number = 0;
  private satellitesVisible: boolean = true;
  private returnModePreferred: boolean;

  constructor(scene: THREE.Scene, options: PlanesShaderOptions = {}) {
    this.scene = scene;
    this.maxSatellites = options.maxPanes || 1000;
    this.baseSize = options.baseSize || 1;
    this.returnModeEnabled = !!options.returnMode;
    this.defaultElevation =
      options.baseElevation !== undefined ? options.baseElevation : 0;
    this.returnModePreferred = this.returnModeEnabled;

    // Initialize arrays
    this.controlPointsPack1 = new Float32Array(this.maxSatellites * 4);
    this.controlPointsPack2 = new Float32Array(this.maxSatellites * 4);
    this.controlPointsPack3 = new Float32Array(this.maxSatellites * 4);
    this.instanceColors = new Float32Array(this.maxSatellites * 3);
    this.instanceScales = new Float32Array(this.maxSatellites);
    this.instanceElevations = new Float32Array(this.maxSatellites);
    this.animationParams = new Float32Array(this.maxSatellites * 4);

    this.initialize();
  }

  /**
   * Initialize the instanced mesh with GPU animation shader
   */
  private initialize(): void {
    // Create satellite geometry
    this.geometry = createSatelliteGeometry();

    // Add per-instance attributes for curve control points
    this.geometry.setAttribute(
      "controlPointsPack1",
      new THREE.InstancedBufferAttribute(this.controlPointsPack1, 4),
    );
    this.geometry.setAttribute(
      "controlPointsPack2",
      new THREE.InstancedBufferAttribute(this.controlPointsPack2, 4),
    );
    this.geometry.setAttribute(
      "controlPointsPack3",
      new THREE.InstancedBufferAttribute(this.controlPointsPack3, 4),
    );

    // Add per-instance attributes for rendering
    this.geometry.setAttribute(
      "instanceColor",
      new THREE.InstancedBufferAttribute(this.instanceColors, 3),
    );
    this.geometry.setAttribute(
      "instanceScale",
      new THREE.InstancedBufferAttribute(this.instanceScales, 1),
    );
    this.geometry.setAttribute(
      "instanceElevation",
      new THREE.InstancedBufferAttribute(this.instanceElevations, 1),
    );
    this.geometry.setAttribute(
      "animationParams",
      new THREE.InstancedBufferAttribute(this.animationParams, 4),
    );

    // Create shader material
    this.material = new THREE.ShaderMaterial({
      uniforms: {
        time: { value: 0.0 },
        returnMode: { value: this.returnModeEnabled ? 1.0 : 0.0 },
        paneVisibility: { value: 1.0 },
      },
      vertexShader,
      fragmentShader,
      side: THREE.DoubleSide,
      transparent: false,
    });

    // Create instanced mesh
    this.instancedMesh = new THREE.InstancedMesh(
      this.geometry,
      this.material,
      this.maxSatellites,
    );

    // Initialize all instances as hidden
    for (let i = 0; i < this.maxSatellites; i++) {
      // Initialize colors to white
      this.instanceColors[i * 3] = 1.0;
      this.instanceColors[i * 3 + 1] = 1.0;
      this.instanceColors[i * 3 + 2] = 1.0;

      // Initialize scale to 0 (hidden)
      this.instanceScales[i] = 0.0;
      this.instanceElevations[i] = this.defaultElevation;

      // Initialize animation params (phase, speed, rotationRate, visible)
      this.animationParams[i * 4] = Math.random(); // phase
      this.animationParams[i * 4 + 1] = 0.1; // speed
      this.animationParams[i * 4 + 2] = 0.5; // rotationRate (self-rotation)
      this.animationParams[i * 4 + 3] = 0.0; // visible (0=hidden)

      // Initialize control points to zero
      this.controlPointsPack1[i * 4] = 0;
      this.controlPointsPack1[i * 4 + 1] = 0;
      this.controlPointsPack1[i * 4 + 2] = 0;
      this.controlPointsPack1[i * 4 + 3] = 0;

      this.controlPointsPack2[i * 4] = 0;
      this.controlPointsPack2[i * 4 + 1] = 0;
      this.controlPointsPack2[i * 4 + 2] = 0;
      this.controlPointsPack2[i * 4 + 3] = 0;

      this.controlPointsPack3[i * 4] = 0;
      this.controlPointsPack3[i * 4 + 1] = 0;
      this.controlPointsPack3[i * 4 + 2] = 0;
      this.controlPointsPack3[i * 4 + 3] = 0;
    }

    // Mark all attributes for initial upload
    this.markAllAttributesNeedUpdate();

    // Add to scene
    this.scene.add(this.instancedMesh);
  }

  /**
   * Set curve control points for a satellite instance
   */
  public setCurveControlPoints(
    index: number,
    controlPoints: THREE.Vector3[],
  ): void {
    if (index < 0 || index >= this.maxSatellites) return;
    if (controlPoints.length < 4) return;

    this.controlPointsPack1[index * 4] = controlPoints[0].x;
    this.controlPointsPack1[index * 4 + 1] = controlPoints[0].y;
    this.controlPointsPack1[index * 4 + 2] = controlPoints[0].z;
    this.controlPointsPack1[index * 4 + 3] = controlPoints[1].x;

    this.controlPointsPack2[index * 4] = controlPoints[1].y;
    this.controlPointsPack2[index * 4 + 1] = controlPoints[1].z;
    this.controlPointsPack2[index * 4 + 2] = controlPoints[2].x;
    this.controlPointsPack2[index * 4 + 3] = controlPoints[2].y;

    this.controlPointsPack3[index * 4] = controlPoints[2].z;
    this.controlPointsPack3[index * 4 + 1] = controlPoints[3].x;
    this.controlPointsPack3[index * 4 + 2] = controlPoints[3].y;
    this.controlPointsPack3[index * 4 + 3] = controlPoints[3].z;

    const attr1 = this.geometry?.getAttribute("controlPointsPack1");
    const attr2 = this.geometry?.getAttribute("controlPointsPack2");
    const attr3 = this.geometry?.getAttribute("controlPointsPack3");
    if (attr1) attr1.needsUpdate = true;
    if (attr2) attr2.needsUpdate = true;
    if (attr3) attr3.needsUpdate = true;
  }

  /**
   * Set color for a satellite instance
   */
  public setPaneColor(index: number, color: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    const col = new THREE.Color(color);
    this.instanceColors[index * 3] = col.r;
    this.instanceColors[index * 3 + 1] = col.g;
    this.instanceColors[index * 3 + 2] = col.b;

    const attr = this.geometry?.getAttribute("instanceColor");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Set size scale for a satellite instance
   */
  public setPaneSize(index: number, size: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    this.instanceScales[index] = size / 100; // Normalize to ~1 for default size

    const attr = this.geometry?.getAttribute("instanceScale");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Set elevation offset
   */
  public setElevationOffset(index: number, offset: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    this.instanceElevations[index] = offset;

    const attr = this.geometry?.getAttribute("instanceElevation");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Set animation speed
   */
  public setAnimationSpeed(index: number, speed: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    this.animationParams[index * 4 + 1] = speed;

    const attr = this.geometry?.getAttribute("animationParams");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Set rotation rate (self-rotation speed)
   */
  public setRotationRate(index: number, rate: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    this.animationParams[index * 4 + 2] = rate;

    const attr = this.geometry?.getAttribute("animationParams");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Set tilt mode (stub - not used for satellites but needed for compatibility)
   */
  public setTiltMode(index: number, mode: string): void {
    // Satellites don't use tilt mode - they always orient along the path
    // This method is here for interface compatibility with PlanesShader
  }

  /**
   * Show a satellite
   */
  public showPane(index: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    this.animationParams[index * 4 + 3] = 1.0;
    this.activeSatellites++;

    const attr = this.geometry?.getAttribute("animationParams");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Hide a satellite
   */
  public hidePane(index: number): void {
    if (index < 0 || index >= this.maxSatellites) return;

    this.animationParams[index * 4 + 3] = 0.0;
    this.activeSatellites = Math.max(0, this.activeSatellites - 1);

    const attr = this.geometry?.getAttribute("animationParams");
    if (attr) attr.needsUpdate = true;
  }

  /**
   * Update the shader - call once per frame
   */
  public update(deltaTime: number, camera?: THREE.Camera): void {
    if (!this.material) return;

    // Update time uniform
    const uniforms = this.material.uniforms;
    uniforms.time.value += deltaTime;
  }

  /**
   * Show/hide all satellites
   */
  public setVisibility(visible: boolean): void {
    this.satellitesVisible = visible;
    if (this.material) {
      this.material.uniforms.paneVisibility.value = visible ? 1.0 : 0.0;
    }
  }

  /**
   * Dispose of resources
   */
  public dispose(): void {
    if (this.instancedMesh) {
      this.scene.remove(this.instancedMesh);
    }
    this.geometry?.dispose();
    this.material?.dispose();
  }

  /**
   * Remove from scene (alias for dispose)
   */
  public remove(): void {
    this.dispose();
  }

  /**
   * Mark all attributes as needing update
   */
  private markAllAttributesNeedUpdate(): void {
    const attrs = ["controlPointsPack1", "controlPointsPack2", "controlPointsPack3", "instanceColor", "instanceScale", "instanceElevation", "animationParams"];
    attrs.forEach((attr) => {
      const attribute = this.geometry?.getAttribute(attr);
      if (attribute) attribute.needsUpdate = true;
    });
  }

  /**
   * Get the instanced mesh (for adding to scene, etc.)
   */
  public getInstancedMesh(): THREE.InstancedMesh | null {
    return this.instancedMesh;
  }
}
