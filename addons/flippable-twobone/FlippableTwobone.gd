@tool
class_name FlippableTwobone
extends SkeletonModification2D

@export_node_path("Node2D") var target_nodepath := NodePath() :
	set(x):
		target_nodepath = x
		_update_target()
	get:
		return target_nodepath
@export var flip_bend_direction := false
@export var joint_one_bone_index := -1 :
	set(x):
		joint_one_bone_index = x
		_update_joint_one_bone()
	get:
		return joint_one_bone_index
@export_node_path("Bone2D") var joint_one_bone := NodePath() :
	set = _set_joint_one_from_bone_path, get = _get_joint_one_bone_path
@export var joint_two_bone_index := -1 :
	set(x):
		joint_two_bone_index = x
		_update_joint_two_bone()
	get:
		return joint_two_bone_index
@export_node_path("Bone2D") var joint_two_bone := NodePath() :
	set = _set_joint_two_from_bone_path, get = _get_joint_two_bone_path

var _stack : SkeletonModificationStack2D

var _target : Node2D
var _bone_a : Bone2D
var _bone_b : Bone2D


func _get_bone_or_null(skeleton: Skeleton2D, idx: int) -> Bone2D:
	if idx < 0 or idx >= skeleton.get_bone_count():
		return null
	return skeleton.get_bone(idx)


func _setup_modification(stack: SkeletonModificationStack2D) -> void:
	_stack = stack
	var skeleton := stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return
	
	_target = skeleton.get_node_or_null(target_nodepath)
	_bone_a = _get_bone_or_null(skeleton, joint_one_bone_index)
	_bone_b = _get_bone_or_null(skeleton, joint_two_bone_index)


func _update_target() -> void:
	if !_stack:
		return
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return
	
	_target = skeleton.get_node_or_null(target_nodepath)


func _update_joint_one_bone() -> void:
	if !_stack:
		return
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return
	
	_bone_a = _get_bone_or_null(skeleton, joint_one_bone_index)


func _set_joint_one_from_bone_path(path: NodePath) -> void:
	if !_stack:
		return
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return
	
	var bone : Bone2D = skeleton.get_node_or_null(path)
	if bone:
		joint_one_bone_index = bone.get_index_in_skeleton()


func _get_joint_one_bone_path() -> NodePath:
	if !_stack or !_bone_a:
		return NodePath()
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return NodePath()
	
	return skeleton.get_path_to(_bone_a)


func _update_joint_two_bone() -> void:
	if !_stack:
		return
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return
	
	_bone_b = _get_bone_or_null(skeleton, joint_two_bone_index)


func _set_joint_two_from_bone_path(path: NodePath) -> void:
	if !_stack:
		return
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return
	
	var bone : Bone2D = skeleton.get_node_or_null(path)
	if bone:
		joint_two_bone_index = bone.get_index_in_skeleton()


func _get_joint_two_bone_path() -> NodePath:
	if !_stack or !_bone_b:
		return NodePath()
	
	var skeleton := _stack.get_skeleton()
	if !skeleton or !skeleton.is_inside_tree():
		return NodePath()
	
	return skeleton.get_path_to(_bone_b)


func _execute(_delta: float):
	if !_target or !_bone_a or !_bone_b:
		return
	
	var bone_a_len := _bone_a.get_length()
	var bone_b_len := _bone_b.get_length()
	
	var sin_angle2 := 0.0
	var cos_angle2 := 1.0
	
	var angle_b := 0.0
	
	var global_xform : Transform2D = _bone_a.get_parent().global_transform
	
	var cos_angle2_denom := 2.0 * bone_a_len * bone_b_len
	if not is_zero_approx(cos_angle2_denom):
		var offset := _target.global_position - _bone_a.global_position
		var target_len_sqr := (offset / global_xform.get_scale()).length_squared()
		var bone_a_len_sqr := bone_a_len * bone_a_len
		var bone_b_len_sqr := bone_b_len * bone_b_len
		
		cos_angle2 = (target_len_sqr - bone_a_len_sqr - bone_b_len_sqr) / cos_angle2_denom
		cos_angle2 = clampf(cos_angle2, -1.0, 1.0);
		
		angle_b = acos(cos_angle2)
		if flip_bend_direction:
			angle_b = -angle_b
		
		sin_angle2 = sin(angle_b)
	
	var tri_adjacent := bone_a_len + bone_b_len * cos_angle2
	var tri_opposite := bone_b_len * sin_angle2
	
	var xform_inv := global_xform.affine_inverse()
	var target_pos := xform_inv * _target.global_position - _bone_a.position
	
	var tan_y := target_pos.y * tri_adjacent - target_pos.x * tri_opposite
	var tan_x := target_pos.x * tri_adjacent + target_pos.y * tri_opposite
	var angle_a := atan2(tan_y, tan_x)
	
	var bone_a_angle := _bone_a.get_bone_angle()
	var bone_b_angle := _bone_b.get_bone_angle()
	_bone_a.rotation = angle_a - bone_a_angle
	_bone_b.rotation = angle_b - angle_difference(bone_a_angle, bone_b_angle)
	
	_stack.get_skeleton().set_bone_local_pose_override(joint_one_bone_index, _bone_a.get_transform(), _stack.strength, true)
	_stack.get_skeleton().set_bone_local_pose_override(joint_two_bone_index, _bone_b.get_transform(), _stack.strength, true)
