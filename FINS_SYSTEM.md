# Fins System Documentation

## What Are Fins?

Fins are perpendicular geometry cards (quads) that complement shell-based fur rendering by filling coverage gaps when viewing fur from oblique angles. Shell fur can appear transparent or "see-through" when viewed from the side because shells are stacked parallel to the mesh surface. Fins solve this by adding cards oriented differently to provide coverage from all angles.

## The Problem Fins Solve

**Shell Fur Side-View Issue:**
- Shell fur works great when viewed head-on (perpendicular to surface)
- When viewed from the side (parallel to surface), you can see through the gaps between shells
- This creates an unrealistic "layered" appearance
- Particularly noticeable on cylindrical or rounded surfaces

**Fins Solution:**
- Add perpendicular geometry cards that fill these gaps
- Oriented to maximize coverage from side angles
- Use the same fur pattern/materials as shells
- Minimal performance impact (16-32 fins typical)

## How Fins Work

### Placement Strategies

Fins can be arranged in different patterns depending on your needs:

1. **Radial** (Default - Best for creatures)
   - Fins arranged in a circle around the mesh
   - Evenly distributed at regular angular intervals
   - Example: 16 fins = one every 22.5 degrees
   - Best for: Characters, creatures, round objects

2. **Grid**
   - Evenly distributed in a grid pattern
   - Covers rectangular or planar surfaces uniformly
   - Best for: Carpets, flat furry surfaces, patches

3. **Edge-Based** (Best quality, experimental)
   - Concentrated near silhouette edges
   - Provides coverage where it's most visible
   - Currently uses radial pattern (full edge detection coming soon)
   - Best for: High-quality hero characters

4. **Sparse** (Best performance)
   - Reduced fin count (25% of specified count)
   - For background objects or distant fur
   - Best for: LOD systems, performance-critical scenes

### Orientation Modes

Fins can be oriented in different ways:

1. **Camera Facing** (Default - Billboard style)
   - Fins always rotate to face the camera
   - Maximum coverage from all viewing angles
   - Updated every frame in `_process()`
   - Best for: General use, dynamic cameras

2. **Shell Perpendicular**
   - Fins oriented perpendicular to fur growth direction
   - More natural, stable appearance
   - No per-frame updates needed
   - Best for: Static scenes, cinematic shots

3. **Fixed Horizontal**
   - Fins locked to horizontal orientation
   - Useful for grass, vertical fur
   - Best for: Grass fields, vertical surfaces

4. **Fixed Vertical**
   - Fins locked to vertical orientation
   - Useful for horizontal surfaces
   - Best for: Carpets, horizontal furry surfaces

## Configuration

### Basic Setup

```gdscript
# Enable fins
$Fur.fins_enabled = true

# Set placement strategy (1=Radial, 2=Grid, 3=Edge, 4=Sparse)
$Fur.fins_placement = 1  # Radial

# Set orientation (0=Camera, 1=Shell Perp, 2=Horiz, 3=Vert)
$Fur.fins_orientation = 0  # Camera facing

# Set fin count (4-64)
$Fur.fins_count = 16
```

### Advanced Parameters

```gdscript
# Density multiplier (0.25-4.0)
# 0.5 = half the fins, 2.0 = double the fins
$Fur.fins_density = 1.0

# Width of each fin in meters (0.01-1.0)
# Smaller = thinner fins, larger = wider coverage
$Fur.fins_width = 0.1

# Alpha boost (0.5-2.0)
# Compensates for fewer samples on fins vs shells
# Higher = more opaque fins
$Fur.fins_alpha_boost = 1.2
```

## Recommended Settings by Use Case

### Mammals (Cats, Dogs, Foxes)

```gdscript
fins_enabled = true
fins_placement = 1  # Radial
fins_orientation = 0  # Camera facing
fins_count = 24
fins_density = 1.0
fins_width = 0.12
fins_alpha_boost = 1.3
```

**Why:** Radial placement provides even coverage around the body. Camera-facing ensures good coverage from all angles. Higher alpha boost makes fur appear denser.

### Grass Fields

```gdscript
fins_enabled = true
fins_placement = 2  # Grid
fins_orientation = 3  # Fixed vertical
fins_count = 16
fins_density = 0.75
fins_width = 0.08
fins_alpha_boost = 1.0
```

**Why:** Grid provides even coverage for large areas. Vertical orientation matches grass growth. Lower density reduces performance impact for large fields.

### Hero Character (Maximum Quality)

```gdscript
fins_enabled = true
fins_placement = 3  # Edge-based
fins_orientation = 0  # Camera facing
fins_count = 32
fins_density = 1.5
fins_width = 0.15
fins_alpha_boost = 1.4
```

**Why:** Edge-based (when fully implemented) provides coverage where most visible. Higher count and density maximize quality. Camera-facing ensures perfect coverage.

### Background Objects (Performance)

```gdscript
fins_enabled = true
fins_placement = 4  # Sparse
fins_orientation = 1  # Shell perpendicular
fins_count = 8
fins_density = 0.5
fins_width = 0.1
fins_alpha_boost = 1.2
```

**Why:** Sparse placement uses minimal fins. Shell perpendicular avoids per-frame updates. Lower count reduces performance impact.

## Performance Impact

### Typical Performance Cost

- **16 fins**: ~2-5% performance impact
- **32 fins**: ~5-10% performance impact
- **64 fins**: ~10-15% performance impact

**Compared to shells:**
- Fins are much cheaper than shells (single quad vs layered geometry)
- 16 fins ≈ cost of 2-3 additional shells
- 32 fins ≈ cost of 4-6 additional shells

### Optimization Tips

1. **Use LOD system**: Fins automatically hide beyond 50% LOD max distance
2. **Camera-facing update**: Only updates when `lod_enabled = true` (camera available)
3. **Sparse mode**: Use for distant/background objects
4. **Density control**: Reduce `fins_density` for better performance
5. **Orientation**: Fixed orientations are cheaper (no per-frame updates)

## Technical Details

### Fin Geometry

- Each fin is a QuadMesh with size: `Vector2(fin_width, fur_length)`
- Positioned strategically based on placement strategy
- Uses custom shader `fur_fin.gdshader`
- No shadow casting (performance optimization)

### Material System

Fins use a specialized shader (`fur_fin.gdshader`) that:
- Samples the same noise textures as shells
- Represents "mid-height" fur (50% of full length)
- Supports texture atlas optimization
- Includes ambient occlusion
- Responds to physics simulation
- Supports rim lighting for visibility

### Physics Integration

Fins respond to the same physics as shells:
- Linear spring physics (movement, gravity)
- Rotational physics (spinning, turning)
- Same stiffness and damping parameters
- Updated in `_physics_process()`

### LOD Integration

Fins have built-in LOD:
- Visible when distance < 50% of `lod_max_distance`
- Automatically hidden at far distances
- Updated per frame with LOD system
- No manual configuration needed

## Common Issues & Solutions

### Fins appear too transparent

**Solution:**
```gdscript
fins_alpha_boost = 1.5  # Increase from default 1.2
```

### Fins cause "doubling" or too dense

**Solution:**
```gdscript
fins_density = 0.5  # Reduce from default 1.0
fins_alpha_boost = 1.0  # Also reduce boost
```

### Fins visible in wrong spots

**Solution:**
- Check `fins_placement` matches your use case
- For creatures: use Radial
- For flat surfaces: use Grid
- Adjust `fins_count` to change coverage

### Performance issues with fins

**Solution:**
```gdscript
fins_count = 8  # Reduce from default 16
fins_placement = 4  # Use Sparse mode
fins_orientation = 1  # Use fixed orientation (no per-frame update)
```

### Fins don't match shell colors

**Solution:**
- Fins automatically use the same textures and colors as shells
- If mismatch occurs, rebuild fur: `$Fur._rebuild_fur()`
- Check that `albedo_color` and textures are set correctly

## Comparison: With vs Without Fins

### Without Fins
- ✗ Gaps visible from side angles
- ✗ "Layered shell" appearance
- ✗ Unrealistic on cylindrical objects
- ✓ Slightly better performance
- ✓ Simpler setup

### With Fins
- ✓ Full coverage from all angles
- ✓ Natural fur appearance
- ✓ Excellent on characters/creatures
- ✓ Minimal performance cost (~2-10%)
- ✓ Multiple placement strategies
- ✗ Slightly more complex

## Future Enhancements

### Planned Features

1. **True Edge Detection**
   - Analyze mesh normals to find silhouette edges
   - Concentrate fins where most visible
   - Adaptive density based on curvature

2. **Fin Combing**
   - Manual control over fin direction
   - Per-fin orientation override
   - Artist-friendly tools

3. **Hybrid Shell-Fin Rendering**
   - Automatic balance between shells and fins
   - Reduce shells, increase fins for performance
   - Quality-matched output

4. **Distance-based Density**
   - More fins when close to camera
   - Fewer fins when far away
   - Smooth transitions

## API Reference

### Properties

```gdscript
# Core settings
@export var fins_enabled: bool = false
@export var fins_placement: int = 1  # FinPlacement enum
@export var fins_orientation: int = 0  # FinOrientation enum

# Count and density
@export_range(4, 64, 1) var fins_count: int = 16
@export_range(0.25, 4.0, 0.25) var fins_density: float = 1.0

# Appearance
@export_range(0.01, 1.0, 0.01) var fins_width: float = 0.1
@export_range(0.5, 2.0, 0.1) var fins_alpha_boost: float = 1.2
```

### Methods (Internal)

```gdscript
# Generate fins based on current settings
fin_manager.generate_fins(length: float, direction: Vector3, shells: int)

# Update fin materials with current fur parameters
_update_fin_materials()

# Update fin orientation (camera-facing mode)
fin_manager.update_orientation(camera: Camera3D)

# Update fin LOD visibility
fin_manager.update_lod(distance: float, max_distance: float)

# Cleanup all fins
fin_manager.cleanup()
```

## Examples

### Example 1: Fluffy Cat

```gdscript
# Main fur settings
number_of_shells = 48
length = 0.15
density = 12.0
scruffiness = 0.4

# Fins configuration
fins_enabled = true
fins_placement = 1  # Radial
fins_orientation = 0  # Camera facing
fins_count = 24
fins_density = 1.2
fins_width = 0.12
fins_alpha_boost = 1.4
```

### Example 2: Short Grass Field

```gdscript
# Main fur settings
number_of_shells = 32
length = 0.08
density = 18.0

# Fins configuration
fins_enabled = true
fins_placement = 2  # Grid
fins_orientation = 3  # Fixed vertical
fins_count = 12
fins_density = 0.75
fins_width = 0.06
fins_alpha_boost = 1.0
```

### Example 3: Performance-Optimized NPC

```gdscript
# Main fur settings (reduced shells)
number_of_shells = 24
length = 0.12

# Fins to compensate for fewer shells
fins_enabled = true
fins_placement = 4  # Sparse
fins_orientation = 1  # Shell perpendicular
fins_count = 12
fins_density = 0.75
fins_width = 0.1
fins_alpha_boost = 1.3
```

## Conclusion

The fins system is a powerful addition to shell fur rendering that solves the side-view transparency issue with minimal performance cost. By choosing the right placement strategy and orientation mode for your use case, you can achieve realistic fur coverage from all viewing angles.

**Key Takeaways:**
- Fins fill gaps that shells can't cover
- ~2-10% performance cost for dramatic quality improvement
- Radial + Camera-facing works for most cases
- Adjust `fins_count` and `fins_density` to balance quality/performance
- Fins respond to physics just like shells
