seeker = class:class_new(object)
function seeker:new(x, y, args)
  self:object(nil, args)
  self:tag('enemy')
  self.x, self.y = x, y
  self.target_x, self.target_y = x, an.h
  self.previous_vx, self.previous_vy = 0, 0
  self.r = 0
  self.sx, self.sy = 1, 1
  self.w, self.h = 14, 6
  self.rx = 3
  self.color = an.colors.red[0]
  self:collider('enemy', 'dynamic', 'rectangle', self.w, self.h)
  self:collider_set_gravity_scale(0.5)
  self:timer()
  self:spring()
  self.push_impulse = {x = 0, y = 0}
  self.base_v = 25
  self.v = self.base_v

  self:stats()
  self:stats_set('hp', 5, 0, 5)
  self:interacts_with_water()
end

function seeker:update(dt)
  self.all_springs_x = self.springs.main.x
  self:interacts_with_water_update(dt)
  
  if self.in_water then
    self.v = self.base_v/3
    if self.being_pushed then
      self:collider_set_gravity_scale(-0.5)
    else
      self:collider_set_gravity_scale(0.2)
    end
  else
    self.v = self.base_v
    self:collider_set_gravity_scale(0.5)
  end

  if self.x < 0 then self:collider_set_position(an.w, self.y) end
  if self.x > an.w then self:collider_set_position(0, self.y) end

  self:collider_update_transform()
  if self.being_pushed then
    local v = math.length(self:collider_get_velocity())
    if v < 25 then
      self.being_pushed = false
      self.push_force = 0
      self.push_angular_impulse = 0
      self:collider_set_damping(0)
      self:collider_set_angular_damping(0)
      self.target_x = self.x
    end
  else
    local sx, sy = self:collider_seek(self.target_x, self.target_y, self.v)
    local px, py = self:collider_separate(32, self.enemies.children, self.v)
    local wx, wy = self:collider_wander(96, 48, 24, self.v)
    self:collider_apply_force(math.limit((sx+px+wx), (sy+py+wy), 1000))
    self:collider_rotate_towards_velocity(0.9, 0.05, dt)

    local vx, vy = self:collider_get_velocity()
    vx, vy = math.limit(vx, vy, self.v)
    self:collider_set_velocity(vx + self.push_impulse.x, vy + self.push_impulse.y)
  end

  self.previous_vx, self.previous_vy = self:collider_get_velocity()

  game:push(self.x, self.y, self.r, self.sx*self.all_springs_x, self.sy*self.all_springs_x)
    game:rectangle(self.x, self.y, self.w, self.h, self.rx, self.rx, self.flashing and flash_color or self.color)
  game:pop()
  show_hp_bar(self, self.color)
end

function seeker:hit_damage(damage, x, y)
  self:flash(0.2)
  self:stats_add('hp', -damage)
  if self.stats.hp.x > 0 then
    self.show_hp_bar = true
    self:timer_after(2, function() self.show_hp_bar = false end, 'show_hp_bar')
  else
    self:die()
  end
end

function seeker:hit_enemy(enemy, x, y)
  if self.just_hit_by_enemy then return end
  self.just_hit_by_enemy = true
  self:timer_after(0.5, function() self.just_hit_by_enemy = false end, 'just_hit_by_enemy')

  self:spring_pull('main', 0.25)
  if self.being_pushed and math.length(self:collider_get_velocity()) > 30 then
    self:flash(0.15)
    self.enemies.arena:add(hit_circle(x, y, {duration = 0.1, rs = 6}))
    enemy:push(self.push_force/2, math.angle_to_point(self.x, self.y, enemy.x, enemy.y), self.push_angular_impulse/2)
  end
end

function seeker:hit_solid(solid, x, y, nx, ny)
  if self.being_pushed then
    local vx, vy = math.bounce(self.previous_vx, self.previous_vy, nx, ny)
    self:collider_set_velocity(vx, vy)
  else
    self:die()
  end
end

function seeker:die(x, y)
  if self.dead then return end
  self.dead = true
  self.enemies.arena:add(hit_circle(x or self.x, y or self.y, {rs = 12, duration = 0.4}):change_color(0.66, self.color))
  for i = 1, an:random_int(4, 6) do self.enemies.arena:add(hit_particle(x or self.x, y or self.y, {v = an:random_float(100, 200), w = an:random_float(5, 8)}):change_color(0.66, self.color)) end
end

function seeker:push(f, r, angular_impulse)
  self.push_force = f
  self.being_pushed = true
  self.push_angular_impulse = angular_impulse or array.random({an:random_float(-48*math.pi, -32*math.pi), an:random_float(32*math.pi, 48*math.pi)})
  self:collider_apply_impulse(f*math.cos(r), f*math.sin(r))
  self:collider_apply_angular_impulse(self.push_angular_impulse)
  self:collider_set_damping(1.5)
  self:collider_set_angular_damping(1.5)
end
