class_name SkillData
extends Resource

enum Element { FIRE, WATER, WOOD, METAL, EARTH }

@export var id: StringName = &""
@export var display_name_ko: String = ""
@export var description_ko: String = ""

@export var element: Element = Element.FIRE

@export_file("*.tscn") var scene_path: String = ""
@export var icon_color: Color = Color.WHITE
@export var icon_texture: Texture2D
