## Collision Zone Resource for Interactive Physics
## Defines a collision detection area for fur interaction
class_name FurCollisionZone
extends Resource

## Shape types for collision detection
enum ShapeType {
	SPHERE,
	CAPSULE,
	BOX,
	CYLINDER
}

## Zone identification
@export var zone_name: String = "Body"

## Shape configuration
@export var shape_type: ShapeType = ShapeType.SPHERE
@export var radius: float = 0.5  ## For sphere/capsule/cylinder
@export var height: float = 1.0  ## For capsule/cylinder
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5)  ## For box

## Position relative to mesh origin
@export var position_offset: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3.ZERO  ## Euler angles

## Influence settings
@export var influence_radius: float = 0.2  ## How far fur is affected beyond collision
@export var displacement_strength: float = 1.0  ## Force multiplier for this zone
@export var enabled: bool = true

## Runtime collision data
var area: Area3D = null
var overlapping_bodies: Array[Node3D] = []
var collision_points: Array[Vector3] = []
var collision_normals: Array[Vector3] = []

func _init() -> void:
	pass

## Create Area3D node with collision shape
func create_area(parent: Node3D) -> Area3D:
	if area != null:
		cleanup()

	area = Area3D.new()
	area.name = "FurCollisionZone_" + zone_name
	area.monitorable = true
	area.monitoring = true

	# Create collision shape based on type
	var collision_shape := CollisionShape3D.new()

	match shape_type:
		ShapeType.SPHERE:
			var sphere := SphereShape3D.new()
			sphere.radius = radius
			collision_shape.shape = sphere

		ShapeType.CAPSULE:
			var capsule := CapsuleShape3D.new()
			capsule.radius = radius
			capsule.height = height
			collision_shape.shape = capsule

		ShapeType.BOX:
			var box := BoxShape3D.new()
			box.size = size
			collision_shape.shape = box

		ShapeType.CYLINDER:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = radius
			cylinder.height = height
			collision_shape.shape = cylinder

	area.add_child(collision_shape)

	# Set position and rotation
	area.position = position_offset
	area.rotation = rotation_offset

	# Connect signals
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)

	parent.add_child(area)

	return area

## Handle body entering zone
func _on_body_entered(body: Node3D) -> void:
	if body not in overlapping_bodies:
		overlapping_bodies.append(body)

## Handle body exiting zone
func _on_body_exited(body: Node3D) -> void:
	overlapping_bodies.erase(body)

## Handle area entering zone
func _on_area_entered(other_area: Area3D) -> void:
	if other_area.get_parent() and other_area.get_parent() not in overlapping_bodies:
		overlapping_bodies.append(other_area.get_parent())

## Handle area exiting zone
func _on_area_exited(other_area: Area3D) -> void:
	if other_area.get_parent():
		overlapping_bodies.erase(other_area.get_parent())

## Update collision data (called per frame)
func update_collision_data(mesh_global_pos: Vector3) -> void:
	collision_points.clear()
	collision_normals.clear()

	if not enabled or area == null:
		return

	var zone_global_pos: Vector3 = area.global_position

	for body in overlapping_bodies:
		if not is_instance_valid(body):
			continue

		var body_pos: Vector3 = body.global_position

		# Calculate collision point (closest point on body to zone center)
		var direction: Vector3 = (body_pos - zone_global_pos).normalized()
		var collision_point: Vector3 = zone_global_pos + direction * radius

		# Collision normal points away from body
		var collision_normal: Vector3 = -direction

		collision_points.append(collision_point)
		collision_normals.append(collision_normal)

## Get displacement for a given world position
func get_displacement_at_position(world_pos: Vector3) -> Vector3:
	if collision_points.size() == 0 or not enabled:
		return Vector3.ZERO

	var total_displacement := Vector3.ZERO

	for i in range(collision_points.size()):
		var collision_point: Vector3 = collision_points[i]
		var collision_normal: Vector3 = collision_normals[i]

		var distance: float = world_pos.distance_to(collision_point)

		# Apply displacement if within influence radius
		if distance < influence_radius:
			var falloff: float = 1.0 - (distance / influence_radius)
			falloff = ease(falloff, -2.0)  # Smooth cubic falloff

			total_displacement += collision_normal * falloff * displacement_strength

	return total_displacement

## Cleanup
func cleanup() -> void:
	if area != null and is_instance_valid(area):
		area.queue_free()
		area = null

	overlapping_bodies.clear()
	collision_points.clear()
	collision_normals.clear()
