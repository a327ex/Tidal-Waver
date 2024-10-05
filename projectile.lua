erojectile = class:class_new(object)
function projectile:new(x, y, args)
  self:object(nil, args)
  self:tag('projectile')
  self.x, self.y = x, y
  self.previous_x, self.previous_y = x, y
  self.previous_vx, self.previous_vy = 0, 0
  self.r = self.r or 0
  self.sx, self.sy = 1, 1
  self.w, self.h = 10, 4
  self.base_v = self.v
  self.color = an.colors.blue_2[0]
  self:collider('projectile', 'dynamic', 'rectangle', self.w, self.h)
  self:collider_set_angle(self.r)
  self:collider_set_fixed_rotation(true)
  self:timer()
  self:spring()
  self:interacts_with_water(5)
end

function projectile:update(dt)
  self:interacts_with_water_update(dt)
  self:collider_update_transform()
  self:collider_move_towards_angle(self.r, self.v)

  self.previous_x, self.previous_y = self.x, self.y
  self.previous_vx, self.previous_vy = self:collider_get_velocity()

  game:push(self.x, self.y, self.r, self.sx*self.springs.main.x, self.sy*self.springs.main.x)
    game:rectangle(self.x, self.y, self.w, self.h, 2, 2, self.flashing and flash_color or self.color)
  game:pop()
end

function projectile:hit_enemy(enemy)
  local x, y = self.x, self.y
  self:die(x, y)
  enemy:spring_pull('main', 0.5)
  enemy:flash(0.15)
  enemy:hit_damage(self.damage, x, y)
  self.projectiles.arena:add(hit_effect(x, y, {s = 1.2}))
  for i = 1, 2 do
    self.projectiles.arena:add(hit_particle(x, y, {r = self.r + an:random_float(-math.pi/3, math.pi/3), w = 6,
      v = an:random_float(25, 125)}):change_color(0.5, an:random_bool(50) and self.color or enemy.color))
  end
end

function projectile:hit_solid(solid, x, y, nx, ny, v)
  local r = math.angle_to_point(x, y, self.x, self.y)
  local x, y = x + 1*math.cos(r), y + 1*math.sin(r)
  self:die(x, y, math.angle(nx, ny))
  self.projectiles.arena:add(projectile_death_effect(x, y, {duration = an:random_float(0.3, 0.4), w = 9}):change_color(0.75, self.color))
end

function projectile:die(x, y, r)
  if self.dead then return end
  self.dead = true
  local x, y = x or self.x, y or self.y
  for i = 1, an:random_int(1, 2) do
    self.projectiles.arena:add(hit_particle(x, y, {r = r and r + an:random_float(-math.pi/3, math.pi/3) or an:random_angle(), v = an:random_float(120, 240),
      duration = an:random_float(0.2, 0.3)}):change_color(nil, self.color))
  end
end
