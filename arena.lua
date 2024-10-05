--{{{ arena 1
arena = class:class_new(object)
function arena:new(x, y, args)
  self:object('arena', args)

  self.water_height = 0.31*an.h
  self:add(solid(an.w/2, an.h + 20, {w = 2*an.w, h = 40}))
  self:add(object('players'))
  self:add(object('enemies'))
  self:add(object('projectiles'))

  self.players:add(player(an.w/2, 40))
  self:timer()

  self:timer_every({2, 4}, function()
    local x = an:random_float(20, an.w - 20)
    if an:random_bool(20) then
      for i = 1, an:random_int(2, 4) do
        self.enemies:add(seeker(x, -64))
      end
    else
      self.enemies:add(seeker(x, -64))
    end
  end)
--}}}

--{{{ water
  -- Water (https://code.tutsplus.com/make-a-splash-with-dynamic-2d-water-effects--gamedev-236t)
  self.water_springs_count = 52
  self.water_spread_value = 0.45
  self:action(function(self, dt) -- advance water simulation as an action
    local left_water_spring_deltas = {}
    local right_water_spring_deltas = {}
    for k = 1, 8 do
      for i = 1, self.water_springs_count do
        local index, back_index, next_index = i, array.get_circular_buffer_index(self.water_springs.children, i-1), array.get_circular_buffer_index(self.water_springs.children, i+1)
        left_water_spring_deltas[index] = self.water_spread_value*(self.water_springs.children[index].y - self.water_springs.children[back_index].y)
        self.water_springs.children[back_index].springs.water.v = self.water_springs.children[back_index].springs.water.v + left_water_spring_deltas[index]
        right_water_spring_deltas[index] = self.water_spread_value*(self.water_springs.children[index].y - self.water_springs.children[next_index].y)
        self.water_springs.children[next_index].springs.water.v = self.water_springs.children[next_index].springs.water.v + right_water_spring_deltas[index]
      end
    end
  end, 'water_springs_update')

  self:late_action(function(self, dt) -- read water simulation outputs as a late action so all water spring objects have had the chance to update
    self.water_surface = {}
    for i, spring in ipairs(self.water_springs.children) do
      local left_spring = self.water_springs.children[array.get_circular_buffer_index(self.water_springs.children, i-1)]
      table.insert(self.water_surface, spring.x - spring.w/2)
      table.insert(self.water_surface, left_spring.y)
      if i == #self.water_springs.children then
        local right_spring = self.water_springs.children[array.get_circular_buffer_index(self.water_springs.children, i+1)]
        table.insert(self.water_surface, spring.x + spring.w/2)
        table.insert(self.water_surface, right_spring.y)
      end
    end
    water_particles:gradient_polyline(self.water_surface, false, 10, an.colors.blue[0])
  end, 'water_springs_late_update')

  local water_height = self.water_height
  local spring_w = an.w/self.water_springs_count
  self.water_spring_w = spring_w
  self:add(object('water_springs'))
  for i = 1, self.water_springs_count do
    self.water_springs:add(object():build(function(self)
      self.x = (i-1)*spring_w + spring_w/2
      self.y = an.h - water_height
      self.w, self.h = spring_w, water_height
      self.index = i
      self.base_y = self.y
      self.base_h = self.h
      self:spring()
      self:spring_add('water', 0, 77, 6)
    end):action(function(self, dt)
      self.y = self.base_y + self.springs.water.x
      self.h = self.base_h - self.springs.water.x
    end):late_action(function(self, dt) -- even though left spring always updates first so this could be an action, when it loops over to the rightmost spring it'll be reading last frame's values
      local left_spring = self.water_springs.children[array.get_circular_buffer_index(self.water_springs.children, self.index-1)]
      water_particles:triangle(self.x - self.w/2, left_spring.y, self.x + self.w/2, self.y, self.x - self.w/2, an.h, 0, an.colors.blue[0])
      water_particles:triangle(self.x + self.w/2, self.y, self.x + self.w/2, an.h, self.x - self.w/2, an.h, 0, an.colors.blue[0])
    end))
  end
end
--}}}

--{{{ arena 2
function arena:update(dt)
  for _, c in ipairs(an:physics_world_get_collision_enter('player', 'solid')) do local player, solid = c.a, c.b; player:hit_solid(solid, c.x, c.y, c.nx, c.ny) end
  for _, c in ipairs(an:physics_world_get_collision_enter('enemy', 'solid')) do local enemy, solid = c.a, c.b; enemy:hit_solid(solid, c.x, c.y, c.nx, c.ny) end
  for _, c in ipairs(an:physics_world_get_collision_enter('projectile', 'solid')) do local projectile, solid = c.a, c.b; projectile:hit_solid(solid, c.x, c.y, c.nx, c.ny) end
  for _, c in ipairs(an:physics_world_get_collision_enter('enemy', 'enemy')) do local enemy_1, enemy_2 = c.a, c.b; enemy_1:hit_enemy(enemy_2, c.x, c.y) end
  for _, c in ipairs(an:physics_world_get_trigger_enter('player', 'enemy')) do local player, enemy = c.a, c.b; player:hit_enemy(enemy) end
  for _, c in ipairs(an:physics_world_get_trigger_enter('projectile', 'enemy')) do local projectile, enemy = c.a, c.b; projectile:hit_enemy(enemy) end

  back:rectangle(an.w/2, an.h/2, 2*an.w, 2*an.h, 0, an.colors.green_1[0])
end

function arena:get_closest_enemy(x, y, rs)
  local min_d, min_i = 1e6, 0
  for i, enemy in ipairs(self.enemies.children) do
    local d = math.distance(x, y, enemy.x, enemy.y)
    if d < min_d and d <= rs then
      min_d = d
      min_i = i
    end
  end
  return self.enemies.children[min_i]
end

function arena:get_closest_water_spring(x)
  local min_dx, min_i = 1e6, 0
  for i, spring in ipairs(self.water_springs.children) do
    local dx = math.abs(spring.x - x)
    if dx < min_dx then
      min_dx = dx
      min_i = i
    end
  end
  return self.water_springs.children[min_i]
end

function arena:get_nearby_enemies(x, y, rs)
  local enemies = {}
  for _, enemy in ipairs(self.enemies.children) do
    if math.distance(x, y, enemy.x, enemy.y) <= rs then
      table.insert(enemies, enemy)
    end
  end
  return enemies
end

--[[
  Creates a splash with a given width around position x. f should be a value in the ~[100, 1000] range for better results.
  The width represents how many springs will be pulled at the same time, as that creates a more realistic water effect.
  Springs to be pulled will be chosen based on position x. Width values in the ~[3, 5] range tend to have better results.
--]]
function arena:splash(f, x, width)
  local springs = self.water_springs.children
  local i = self:get_closest_water_spring(x).index
  if width % 2 == 0 then
    local w = width/2
    for j = i-w+1, i+w do
      springs[array.get_circular_buffer_index(springs, j)].springs.water.v = f
    end
  else
    local w = math.floor(width/2)
    for j = i-w, i+w do
      springs[array.get_circular_buffer_index(springs, j)].springs.water.v = f
    end
  end
end
--}}}
