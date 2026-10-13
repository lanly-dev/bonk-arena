"""Build the BONK! arena brawler scene headless, attach traits, publish HTML5."""
import bpy
import math
import mathutils
import os

import armory
import arm.utils
import arm.props

armory.restart_armory(bpy.context)

PROJ = '/home/hatch/workspace/armory/bonk-arena'

# ---------------- wipe ----------------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# ---------------- materials ----------------
def make_mat(name, rgb, emission=0.0, ergb=(1, 1, 1), metallic=0.0, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*rgb, 1.0)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = rough
    if emission > 0:
        bsdf.inputs['Emission Color'].default_value = (*ergb, 1.0)
        bsdf.inputs['Emission Strength'].default_value = emission
    return m

DARK = make_mat('Dark', (0.12, 0.13, 0.16), rough=0.7)
WHITE = make_mat('White', (0.95, 0.95, 0.95), emission=0.4, ergb=(1, 1, 1))
GROUND_MAT = make_mat('Ground', (0.09, 0.11, 0.16), rough=0.95)
WALL_MAT = make_mat('Wall', (0.4, 0.2, 0.05), emission=2.0, ergb=(1.0, 0.55, 0.1))
ZONE_MAT = make_mat('Zone', (0.4, 0.05, 0.05), emission=3.0, ergb=(1.0, 0.15, 0.1))
PILLAR_MAT = make_mat('Pillar', (0.35, 0.37, 0.42), rough=0.8)
PROJ_MAT = make_mat('Proj', (0.5, 0.2, 0.05), emission=2.5, ergb=(1.0, 0.5, 0.1))

def body_mat(name, rgb):
    return make_mat(name, rgb, metallic=0.15, rough=0.5)

# ---------------- helpers ----------------
def active_named(name):
    o = bpy.context.active_object
    o.name = name
    return o

def parent_to(child, parent):
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()

def add_trait(obj, cls):
    t = obj.arm_traitlist.add()
    t.type_prop = 'Haxe Script'
    t.class_name_prop = cls  # package comes from Sources/<package>/ dir

def look_at(obj, tx, ty, tz):
    d = mathutils.Vector((tx, ty, tz)) - obj.location
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()

# ---------------- world ----------------
if 'Arm' not in bpy.data.worlds:
    arm.props.create_wrd()
wrd = bpy.data.worlds['Arm']

world = bpy.data.worlds['World']
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.015, 0.02, 0.045, 1.0)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0

# ---------------- arena ----------------
bpy.ops.mesh.primitive_cylinder_add(vertices=72, radius=30, depth=0.2, location=(0, 0, -0.1))
ground = active_named('Ground')
ground.active_material = GROUND_MAT

bpy.ops.mesh.primitive_torus_add(major_radius=22, minor_radius=0.6,
                                major_segments=72, minor_segments=12, location=(0, 0, 0.6))
wall = active_named('Wall')
wall.active_material = WALL_MAT

bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.14,
                                major_segments=96, minor_segments=8, location=(0, 0, 0.35))
zone_ring = active_named('ZoneRing')
zone_ring.active_material = ZONE_MAT
add_trait(zone_ring, 'Zone')

# pillars
bpy.ops.object.empty_add(location=(0, 0, 0))
pillars = active_named('Pillars')
for i, (px, py) in enumerate([(8, 6), (-9, 4), (5, -9), (-6, -8), (3, 13)]):
    bpy.ops.mesh.primitive_cylinder_add(radius=1.3, depth=5, location=(px, py, 2.5))
    p = active_named('Pillar_%d' % i)
    p.active_material = PILLAR_MAT
    parent_to(p, pillars)

# ---------------- fighters ----------------
def make_fighter(name, x, y, rgb):
    bpy.ops.object.empty_add(location=(x, y, 0))
    root = active_named(name)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, segments=24, ring_count=16, location=(0, 0, 1.05))
    body = active_named(name + '_Body')
    body.scale = (1, 1, 1.15)
    body.active_material = body_mat(name + '_BodyMat', rgb)
    parent_to(body, root)

    bpy.ops.mesh.primitive_cylinder_add(radius=1.02, depth=0.25, location=(0, 0, 0.14))
    base = active_named(name + '_Base')
    base.active_material = DARK
    parent_to(base, root)

    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.95, 1.05))
    gun = active_named(name + '_Gun')
    gun.scale = (0.35, 1.15, 0.35)
    gun.active_material = DARK
    parent_to(gun, root)

    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, segments=16, ring_count=8, location=(0, 0.85, 1.3))
    eye = active_named(name + '_Eye')
    eye.active_material = WHITE
    parent_to(eye, root)

    add_trait(root, 'Fighter')
    return root

player = make_fighter('Player', 0, -10, (0.0, 0.74, 0.83))
add_trait(player, 'Player')

make_fighter('Bot1', 0, 10, (0.96, 0.26, 0.21))
make_fighter('Bot2', -10, 0, (1.0, 0.6, 0.1))
make_fighter('Bot3', 10, 0, (0.61, 0.35, 0.75))
for b in ['Bot1', 'Bot2', 'Bot3']:
    add_trait(bpy.data.objects[b], 'Bot')

# ---------------- projectile template ----------------
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, segments=16, ring_count=8, location=(0, 0, -50))
pt = active_named('ProjectileTemplate')
pt.active_material = PROJ_MAT
add_trait(pt, 'Projectile')

# ---------------- game controller ----------------
bpy.ops.object.empty_add(location=(0, 0, 0))
game = active_named('Game')
add_trait(game, 'Game')

# ---------------- camera ----------------
bpy.ops.object.camera_add(location=(0, -34, 38))
cam = active_named('Camera')
look_at(cam, 0, 0, 2)
cam.data.angle = math.radians(55)
bpy.context.scene.camera = cam
add_trait(cam, 'CameraRig')

# ---------------- sun ----------------
bpy.ops.object.light_add(type='SUN', location=(12, -8, 25))
sun = active_named('Sun')
sun.data.energy = 3.0
look_at(sun, 0, 0, 0)

# ---------------- save, export, publish ----------------
blend_path = os.path.join(PROJ, 'bonk.blend')
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

arm.utils.fetch_script_names()
print('scripts found:', [s.name for s in wrd.arm_scripts_list])

if len(wrd.arm_exporterlist) == 0:
    item = wrd.arm_exporterlist.add()
    item.name = 'html5'
    item.arm_project_target = 'html5'
    item.arm_project_scene = bpy.context.scene
    wrd.arm_exporterlist_index = 0

print('--- publishing BONK! ---')
res = bpy.ops.arm.publish_project()
print('publish result:', res)

# Make the exported page responsive (mobile-friendly, no scrollbars)
html_path = os.path.join(PROJ, 'build_bonk', 'html5', 'index.html')
if os.path.exists(html_path):
    with open(html_path) as f:
        html = f.read()
    html = html.replace(
        "<meta charset='utf-8'/>",
        "<meta charset='utf-8'/>\n    <meta name='viewport' content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no'/>\n"
        "    <style>html,body{margin:0;padding:0;background:#05060a;height:100%;overflow:hidden}"
        "body{display:flex;align-items:center;justify-content:center}"
        "p{margin:0}canvas{max-width:100vw;max-height:100vh;width:auto;height:auto;touch-action:none}</style>"
    )
    with open(html_path, 'w') as f:
        f.write(html)
    print('patched index.html for responsive canvas')

print('MAKE_GAME_DONE')
