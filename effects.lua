visual_effect = class:class_new()
function visual_effect:visual_effect()
  self.tags.visual_effect = true
  return self
end

function visual_effect:change_color(s, color)
  self:timer_after(self.duration*(s or 0.5), function() self.color = color end)
  return self
end
object:class_add(visual_effect)


water_particle = class:class_new(object)
function water_particle:new(x, y, args)
  self:object(nil, args)
  self.x, self.y = x, y
  self.r = self.r or an:random_angle()
  self.v = self.v or an:random_float(50, 100)
  self.rs = 10
  self.color = (args and args.color) or an.colors.blue[0]
  self.vx, self.vy = self.v*math.cos(self.r), self.v*math.sin(self.r)
end

function water_particle:update(dt)
  self.vy = self.vy + 386*dt
  self.x = self.x + self.vx*dt
  self.y = self.y + self.vy*dt
  if self.x < 0 then self.x = an.w end
  if self.x > an.w then self.x = 0 end
  if self.y > an.h then self.dead = true end
  -- TODO: implement equivalent
  water_particles:gradient_circle(self.x, self.y, self.rs, self.color)
end


projectile_death_effect = class:class_new(object)
function projectile_death_effect:new(x, y, args)
  self:object(nil, args)
  self.x, self.y = x, y
  self.r = self.r or 0
  self.w = self.w or 8
  self.duration = self.duration or 0.25
  self.color = (args and args.color) or flash_color
  self:timer()
  self:timer_after(self.duration, function() self.dead = true end)
  self:spring()
  self:spring_pull('main', 0.25)
  self:visual_effect()
end

function projectile_death_effect:update(dt)
  effects:push(self.x, self.y, self.r, self.springs.main.x, self.springs.main.x)
    effects:rectangle(self.x, self.y, self.w, self.w, 3, 3, self.color)
  effects:pop()
end


hit_circle = class:class_new(object)
function hit_circle:new(x, y, args)
  self:object(nil, args)
  self.x, self.y = x, y
  self.rs = self.rs or 12
  self.duration = self.duration or an:random_float(0.05, 0.2)
  self.color = args.color or flash_color
  self:timer()
  self:timer_tween(self.duration, self, {rs = 0}, math.cubic_in_out, function() self.dead = true end)
  self:visual_effect()
end

function hit_circle:update(dt)
  effects:circle(self.x, self.y, self.rs, self.color)
end

hit_particle = class:class_new(object)
function hit_particle:new(x, y, args)
  self:object(nil, args)
  self.x, self.y = x, y
  self.r = self.r or an:random_angle()
  self.v = self.v or an:random_float(100, 250)
  self.angular_v = self.angular_v or 0
  self.w = self.w or math.remap(self.v, 100, 250, 7, 10)
  self.h = self.h or self.w/2
  self.rs = 2
  self.duration = self.duration or an:random_float(0.2, 0.6)
  self.color = (args and args.color) or flash_color
  self:timer()
  self:timer_tween(self.duration, self, {v = 0, w = 2, h = 2, rs = 0}, math.sine_in_out, function() self.dead = true end)
  self:visual_effect()
end

function hit_particle:update(dt)
  self.r = self.r + self.angular_v*dt
  self.x = self.x + self.v*math.cos(self.r)*dt
  self.y = self.y + self.v*math.sin(self.r)*dt
  effects:push(self.x, self.y, self.r)
    effects:rectangle(self.x, self.y, self.w, self.h, self.rs, self.rs, self.color)
  effects:pop()
end

hit_effect = class:class_new(object)
function hit_effect:new(x, y, args)
  self:object(nil, args)
  self.x, self.y = x, y
  self.r = an:random_angle()
  self.sx, self.sy = self.s or 1, self.s or 1
  self.color = flash_color
  self:add(object('hit_effect_animation'):animation('hit_effect', 0.04, 'once', {[0] = function() self.dead = true end}))
end

function hit_effect:update(dt)
  effects:draw_animation(self.hit_effect_animation, self.x, self.y, self.r, self.sx, self.sy, flash_color)
end
--}}}
