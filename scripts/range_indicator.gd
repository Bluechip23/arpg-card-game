class_name RangeIndicator
extends Node3D

## Visual circle overlay showing card range around the player on the ground plane.

var range_radius: float = 5.0
var color: Color = Color(0.6, 0.6, 0.7, 0.15)

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = true
	_mesh_instance.material_override = _material

func _build_mesh() -> void:
	var mesh = ImmediateMesh.new()
	_mesh_instance.mesh = mesh

	var segments = 48
	var center = Vector3(0, 0.02, 0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 = TAU * i / segments
		var a1 = TAU * (i + 1) / segments
		mesh.surface_add_vertex(center)
		mesh.surface_add_vertex(Vector3(cos(a0) * range_radius, 0.02, sin(a0) * range_radius))
		mesh.surface_add_vertex(Vector3(cos(a1) * range_radius, 0.02, sin(a1) * range_radius))
	mesh.surface_end()

func show_range(radius: float) -> void:
	range_radius = radius
	_build_mesh()
	visible = true

func hide_range() -> void:
	visible = false
