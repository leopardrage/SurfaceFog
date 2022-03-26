# Surface Fog

**Surface Fog** is a study case project that shows how to achieve a fog effect that involves specific surfaces in the scene.

## Requirements

- Unity 2020.3.16f1+
- Unity 2021.1.17f1+

What drives the requirements is the Package Requirements feature, that allows the SurfaceFog shader to correctly compile with the Built-In RP, avoiding errors due to missing URP packages.

## Compatibility

- Built-In Rendering Pipeline
- Universal Rendering Pipeline

## Get Started

- **Enable Depth Texture**. You can do this in many ways. Here are the most common approaches:
  - Activating Depth Texture on your camera. In URP, set the **Depth Texture** option to **On** for your camera (or set it globally in your pipeline settings asset). In Built-In RP, set the **Camera.DepthTextureMode** for your camera via script.
  - Having a non-black non-0 intensity **directional light** in the scene will automatically create a depth texture in Built-In RP, while in URP you'll have to use the Screen Space Shadow Maps render feature.
  - Enable **Deferred Render Path**.
- Create a material that uses the **Surface Fog** shader and apply it to a mesh.

All regular geometry that falls through this mash will fade according to the material settings.

This is useful to create a fog at the bottom of an environment, such as a room or a landscape.

![](SurfaceFog.png)

Check the **FogExample** scene for a reference.

### Note

This is not a volumetric fog effect, so it works only when the camera is above the mesh that uses the fog, not when inside it.

## Limitations
- **Surface Fog** doesn't work with orthographic cameras and oblique frustrums.
- Transparent objects would be unaffected by the fog.

## Performance Considerations
The **Surface Fog** shader does cheap operations. However it relies on the depth texture to work, which takes a full scene draw of ShadowCaster passes to fill it. If you were already using the Depth Texture, because you were already using features that need it (typical examples: directional light in Built-In RP or Deferred Rendering Path), you won't experience almost any performance drop. Otherwise this new draw cicle will be added, which is a little expansive.

## TODO
- Add compatibility with orthographic cameras.
- Apply fog effect to transparent objects.
