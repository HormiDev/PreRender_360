@tool
extends HBoxContainer

signal rotation_changed(pitch: float, yaw: float, roll: float)
signal rotation_delta(pitch_delta: float, yaw_delta: float, roll_delta: float)

var sphere: Control = null
var spin_x: SpinBox = null
var spin_y: SpinBox = null
var spin_z: SpinBox = null

# ---------- HELPERS ----------
# Description: Recursively searches for a sphere control node by checking for required methods and signals.
# Args: node (Node) — root node to search from
# Returns: Control — sphere node if found, null otherwise
func _find_sphere_node(node: Node) -> Control:
	if node == null:
		return null
	if node is Control and node.has_method("set_sphere_rotation") and node.has_signal("rotation_changed"):
		return node as Control
	for child in node.get_children():
		var found := _find_sphere_node(child)
		if found:
			return found
	return null

# ---------- READY ----------
# Description: Initializes the wrapper by finding sphere and spinbox nodes, connecting signals, and configuring controls.
# Args: none
# Returns: void
func _ready() -> void:
	sphere = _find_sphere_node(self)
	if sphere == null:
		var by_name = find_child("SphereCanvas", true, false) as Control
		if by_name:
			sphere = by_name

	_locate_spinboxes_from_controls()

	if sphere:
		call_deferred("_deferred_setup_sphere")

	if spin_x:
		spin_x.min_value = -180.0
		spin_x.max_value = 180.0
		spin_x.step = 0.1
		spin_x.connect("value_changed", Callable(self, "_on_spin_changed"))
	if spin_y:
		spin_y.min_value = -180.0
		spin_y.max_value = 180.0
		spin_y.step = 0.1
		spin_y.connect("value_changed", Callable(self, "_on_spin_changed"))
	if spin_z:
		spin_z.min_value = -180.0
		spin_z.max_value = 180.0
		spin_z.step = 0.1
		spin_z.connect("value_changed", Callable(self, "_on_spin_changed"))

	_update_spins_from_sphere()

# Description: Deferred setup to connect sphere rotation signal after tree is ready.
# Args: none
# Returns: void
func _deferred_setup_sphere() -> void:
	if not sphere:
		return
	if sphere.has_signal("rotation_changed"):
		sphere.connect("rotation_changed", Callable(self, "_on_sphere_rotation_changed"))
	if sphere.has_signal("rotation_delta"):
		sphere.connect("rotation_delta", Callable(self, "_on_sphere_rotation_delta"))
	_update_spins_from_sphere()

# Description: Locates and assigns spinbox nodes from the Controls container by scanning row labels.
# Args: none
# Returns: void
func _locate_spinboxes_from_controls() -> void:
	var controls = get_node_or_null("Controls")
	if controls == null:
		controls = find_child("Controls", true, false)
	if controls == null:
		return
	for row in controls.get_children():
		if not (row is Node):
			continue
		var label_node: Label = null
		var spin_node: SpinBox = null
		for child in row.get_children():
			if child is Label and label_node == null:
				label_node = child
			elif child is SpinBox and spin_node == null:
				spin_node = child
		if label_node and spin_node:
			var key := str(label_node.text).strip_edges().to_upper()
			match key:
				"X":
					spin_x = spin_node
				"Y":
					spin_y = spin_node
				"Z":
					spin_z = spin_node
				_:
					if spin_x == null:
						spin_x = spin_node
					elif spin_y == null:
						spin_y = spin_node
					elif spin_z == null:
						spin_z = spin_node

# ---------- SIGNAL HANDLERS ----------
# Description: Updates spinbox values when sphere rotation changes, blocking signals to prevent loops.
# Args: pitch (float) — X rotation, yaw (float) — Y rotation, roll (float) — Z rotation
# Returns: void
func _on_sphere_rotation_changed(pitch: float, yaw: float, roll: float) -> void:
	if spin_x:
		spin_x.set_block_signals(true)
	if spin_y:
		spin_y.set_block_signals(true)
	if spin_z:
		spin_z.set_block_signals(true)
	if spin_x:
		spin_x.value = pitch
	if spin_y:
		spin_y.value = yaw
	if spin_z:
		spin_z.value = roll
	if spin_x:
		spin_x.set_block_signals(false)
	if spin_y:
		spin_y.set_block_signals(false)
	if spin_z:
		spin_z.set_block_signals(false)
	emit_signal("rotation_changed", pitch, yaw, roll)

func _on_sphere_rotation_delta(pitch_delta: float, yaw_delta: float, roll_delta: float) -> void:
	emit_signal("rotation_delta", pitch_delta, yaw_delta, roll_delta)

# Description: Updates sphere rotation when a spinbox value changes.
# Args: value (float) — new spinbox value (unused, uses all spinbox values)
# Returns: void
func _on_spin_changed(value: float) -> void:
	var p: float = spin_x.value if spin_x else 0.0
	var y: float = spin_y.value if spin_y else 0.0
	var r: float = spin_z.value if spin_z else 0.0
	if sphere and sphere.has_method("set_sphere_rotation"):
		sphere.call("set_sphere_rotation", p, y, r)
	emit_signal("rotation_changed", p, y, r)

# ---------- GETTERS & SETTERS ----------
# Description: Synchronizes spinbox values from the sphere's current rotation state.
# Args: none
# Returns: void
func _update_spins_from_sphere() -> void:
	if not sphere:
		return
	if sphere.has_method("_sync_rotation_degrees_from_basis"):
		sphere.call("_sync_rotation_degrees_from_basis")
	var p: float = 0.0
	var y: float = 0.0
	var r: float = 0.0
	if sphere.has_method("get_pitch_degrees"):
		p = sphere.call("get_pitch_degrees")
	else:
		p = sphere.get("pitch_degrees")
	if sphere.has_method("get_yaw_degrees"):
		y = sphere.call("get_yaw_degrees")
	else:
		y = sphere.get("yaw_degrees")
	if sphere.has_method("get_roll_degrees"):
		r = sphere.call("get_roll_degrees")
	else:
		r = sphere.get("roll_degrees")

	if spin_x:
		spin_x.value = p
	if spin_y:
		spin_y.value = y
	if spin_z:
		spin_z.value = r

# Description: Returns the current rotation as euler angles in degrees from spinbox values.
# Args: none
# Returns: Vector3 — (pitch, yaw, roll) in degrees
func get_rotation_euler_degrees() -> Vector3:
	return Vector3(spin_x.value if spin_x else 0.0, spin_y.value if spin_y else 0.0, spin_z.value if spin_z else 0.0)

# Description: Sets the rotation using euler angles in degrees and updates both sphere and spinboxes.
# Args: pitch (float) — X rotation, yaw (float) — Y rotation, roll (float) — Z rotation
# Returns: void
func set_rotation_euler_degrees(pitch: float, yaw: float, roll: float) -> void:
	if spin_x:
		spin_x.value = pitch
	if spin_y:
		spin_y.value = yaw
	if spin_z:
		spin_z.value = roll
	if sphere and sphere.has_method("set_sphere_rotation"):
		sphere.call("set_sphere_rotation", pitch, yaw, roll)
	emit_signal("rotation_changed", pitch, yaw, roll)
