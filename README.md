# PreRender_Tool

This program is a **3D model prerendering tool** developed in Godot 4, designed to automatically generate high-quality 2D captures from 3D models.

## Main Features

- 📦 **3D Model Loading**
  - Default model included (`robot`)
  - **GLB/GLTF model import at runtime**

- 🎛️ **Interactive Controls**
  - Render resolution adjustment
  - Number of captures for 360° rendering
  - Model scaling
  - Model rotation (up/down and Z axis)
  - Directional light rotation
  - Light intensity control

- 💡 **Lighting**
  - Real-time configurable DirectionalLight3D
  - Ideal for adjusting shadows and volume before capturing

- 📸 **360° Capture**
  - Renders multiple angles of the model
  - Exports images in **PNG, JPG, WEBP, or XPM**
  - Automatic output to a configured folder

## Main Use Cases

Designed for:
- Generating 2D sprites from 3D models
- Creating technical renders or previews
- Preparing assets for games, catalogs, or external tools

The entire workflow runs **in real time and without relying on the editor**, making the tool ideal for automated pipelines.

---  
Developed with Godot 4 🚀
