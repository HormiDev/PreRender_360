# 🚀 PreRender_360 Tool — 3D to 2D Capture Automation (Godot 4)

🌐 **Browser version:**  
[![Play on itch.io](https://img.shields.io/badge/Play%20in%20Browser-itch.io-FA5C5C?style=for-the-badge&logo=itchdotio&logoColor=white)](https://hormidev.itch.io/prerender-360)


---

📦 **Download latest release:**  
[![Download Latest Release](https://img.shields.io/badge/Download-Latest%20Release-blue?style=for-the-badge&logo=github)](https://github.com/HormiDev/PreRender_360/releases/latest)

---

**Generate high-quality 2D renders from 3D models in seconds.**  
Built for fast workflows, sprite creation, and technical previews without hassle.

---

## What is PreRender_360 Tool?

PreRender Tool is a real-time 3D prerendering application built with Godot 4 that automates the creation of 2D captures from 3D models.

It was originally created to prerender models for a raycasting project called **[Cub_3D](https://github.com/HormiDev/42_cub_3D)**. After finishing that project, I decided to polish it a bit and release it as a standalone tool.

It’s **open source**, so you can explore it, modify it, or use it as a base for your own projects.

I’m not actively maintaining it all the time, but any bug reports, strange errors, suggestions, or improvements are more than welcome — either through issues or pull requests.

Ideal for developers, artists, and anyone who wants to convert 3D into 2D without wasting time.

---

## Why use it?

If you need to turn 3D models into clean, consistent 2D images quickly, this tool saves you a lot of work.

I originally used it to simulate a 3D effect by creating animations from multiple captures of a scene, but it also works perfectly for generating animated 2D sprites from 3D models, preparing assets, or experimenting with whatever you can imagine.

**No editor setup. No manual rendering. Just load, tweak, and export.**

---

## Features

### 3D Model Support
- Included example model (robot)
- Runtime import of **GLB / GLTF**
- Fast iteration without restarting

### Scene Control
- Adjustable render resolution
- Configurable capture count (360° rendering)
- Model scaling
- Rotation controls (vertical + Z axis)

### Lighting
- Real-time directional light
- Adjustable light rotation
- Intensity control

### Capture & Export
- Automatic multi-angle rendering
- Export as **sprite atlas**, **individual images**, or **animated GIF**
- Available formats:
  - PNG
  - JPG
  - WEBP
  - GIF
  - XPM
- Automatic output folder saving

---

## Built for speed

Designed for fast iteration and easy integration into automated pipelines.  
Less manual work, more consistent results.

---

## Technical Info

- Engine: Godot 4  
- Input: GLB / GLTF  
- Output: PNG, JPG, WEBP, GIF, XPM

---

## Final note

If it saves you time or helps your workflow, then it did its job 🙂
