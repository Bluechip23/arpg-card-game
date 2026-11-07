extends RefCounted

## Small mesh builders more than one scene used to write out for itself.

## A sphere of radius `r` (its height is the diameter).
static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s
