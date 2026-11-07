extends RefCounted

## The scroll-the-view-off-the-character rule the battle map and the town
## share: the pan moves on the ground plane only and stays within `limit`
## of the follow point on each axis.

## The pan after moving it by `delta`.
static func panned(pan: Vector3, delta: Vector3, limit: float) -> Vector3:
	var p := pan + Vector3(delta.x, 0, delta.z)
	p.x = clampf(p.x, -limit, limit)
	p.z = clampf(p.z, -limit, limit)
	return p
