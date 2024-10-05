require 'anchor'
require 'arena'
require 'player'
require 'interacts_with_water'
require 'seeker'
require 'projectile'



--{{{ general
function show_hp_bar(self, color)
  if self.show_hp_bar then
    ui:push(self.x, self.y, 0, self.sx*self.all_springs_x, self.sy*self.all_springs_x)
    ui:line(self.x - 0.5*self.w, self.y - self.h, self.x + 0.5*self.w, self.y - self.h, an.colors.black[0])
    ui:line(self.x - 0.5*self.w, self.y - self.h, self.x - 0.5*self.w + math.remap(self.stats.hp.x, 0, self.stats.hp.max, 0, 1)*self.w, self.y - self.h,
      self.flashing and flash_color or (color and an.colors.red[0]))
    ui:pop()
  end
end
--}}}

--{{{ solid
solid = class:class_new(object)
function solid:new(x, y, args)
  self:object(nil, args)
  self.x, self.y = x, y
  self.color = an.colors.white[0]
  self:collider('solid', 'static', 'rectangle', self.w, self.h)
end

function solid:update(dt)
  -- front:rectangle(self.x, self.y, self.w, self.h, 0, self.color)
end
--}}}
--]===]

require 'anchor'

function init()
  an:anchor_start('Tidal Waver', 480, 270, 3, 3, 'tidal_waver')
  an:input_bind('left', {'key:a', 'key:left', 'button:dpleft', 'axis:leftx-'})
  an:input_bind('right', {'key:d', 'key:right', 'button:dpright', 'axis:leftx+'})
  an:input_bind('up', {'key:w', 'key:up', 'button:dpup', 'axis:lefty-'})
  an:input_bind('down', {'key:s', 'key:down', 'button:dpdown', 'axis:lefty+'})
  an:input_bind('action_1', {'key:space', 'key:z', 'mouse:1', 'button:fleft', 'button:fdown', 'axis:triggerright'})
  an:input_bind('action_2', {'key:escape', 'key:x', 'mouse:2', 'button:fright', 'button:fup', 'axis:triggerleft'})

  an:shader('replace', nil, [[
    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
      return vec4(color.rgb, Texel(texture, tc).a);
    }
  ]])

  an:shader('shadow', nil, [[
    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
      return vec4(0.15, 0.15, 0.15, Texel(texture, tc).a*0.5);
    }
  ]])

  an:shader('metaballs', nil, [[
    uniform Image tex;

    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
      vec4 pixel = Texel(tex, tc);
      return pixel.b > 0.6 ? vec4(pixel.rgb, 1.0) : vec4(0.0);
    }
  ]])

  an:font('JPN12', 'assets/Mx437_DOS-V_re_JPN12.ttf', 12)
  an:font('FatPixel', 'assets/FatPixelFont.ttf', 8)
  an:image('hit_effect', 'assets/hit_effect.png')
  an:animation_frames('hit_effect', 'hit_effect', 96, 48)

  back = object():layer()
  shadow = object():layer()
  shadow:layer_add_canvas('water_particles')
  water_particles = object():layer()
  water_particles:layer_add_canvas('metaballs')
  game = object():layer()
  effects = object():layer()
  front = object():layer()
  ui = object():layer()

  function an:draw_layers()
    back:layer_draw_commands()
    game:layer_draw_commands()
    effects:layer_draw_commands()
    front:layer_draw_commands()
    ui:layer_draw_commands()

    shadow:layer_draw_to_canvas('main', function()
      game:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
      effects:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
      front:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
      ui:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
    end)

    self:layer_draw_to_canvas('main', function()
      back:layer_draw()
      shadow.x, shadow.y = 1.5, 1.5
      shadow:layer_draw()
      game:layer_draw()
      effects:layer_draw()
      front:layer_draw()
      ui:layer_draw()
    end)

    self:layer_draw('main', 0, 0, 0, self.sx, self.sy)
  end

  --{{{ layer draw with metaballs shader, need to test it gradually
  --[[
  function an:draw_layers()
    back:layer_draw_commands()
    water_particles:layer_draw_commands()
    game:layer_draw_commands()
    effects:layer_draw_commands()
    front:layer_draw_commands()
    ui:layer_draw_commands()

    shadow:layer_draw_to_canvas('main', function()
      game:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
      effects:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
      front:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
      ui:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true)
    end)
    water_particles:layer_draw_to_canvas('metaballs', function() water_particles:layer_draw('main', 0, 0, 0, 1, 1, an.colors.white[0], 'metaballs', true) end)
    shadow:layer_draw_to_canvas('water_particles', function() water_particles:layer_draw('metaballs', 0, 0, 0, 1, 1, an.colors.white[0], 'shadow', true) end)

    self:layer_draw_to_canvas('main', function()
      back:layer_draw()
      shadow.x, shadow.y = 1.5, 1.5
      shadow:layer_draw('water_particles')
      water_particles:layer_draw('metaballs')
      shadow:layer_draw()
      game:layer_draw()
      effects:layer_draw()
      front:layer_draw()
      ui:layer_draw()
    end)

    self:layer_draw('main', 0, 0, 0, self.sx, self.sy)
  end
  ]]--
  --}}}
  
  an:physics_world_set_meter(32)
  an:physics_world_set_gravity(0, 128)
  an:physics_world_set_physics_tags({'player', 'projectile', 'enemy', 'solid'})
  an:physics_world_disable_collision_between('enemy', {'player', 'projectile'})
  an:physics_world_disable_collision_between('player', {'enemy', 'projectile'})
  an:physics_world_disable_collision_between('projectile', {'projectile'})
  an:physics_world_enable_trigger_between('player', {'enemy'})
  an:physics_world_enable_trigger_between('projectile', {'enemy', 'player', 'projectile'})

  flash_color = an.colors.white[0]
  an:add(arena())
end
