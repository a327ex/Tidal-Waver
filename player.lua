--{{{ player 1
player = class:class_new(object)
function player:new(x, y, args)
  self:object('player', args)
  self.x, self.y = x, y
  self.r = 0
  self.sx, self.sy = 1, 1
  self.w, self.h = 12, 8
  self.rx = 3
  self.color = an.colors.blue_2[0]
  self:collider('player', 'dynamic', 'rectangle', self.w, self.h)
  self:collider_set_fixed_rotation(true)
  self:collider_set_restitution(0.9)
  self:timer()
  self:spring()
  self:spring_add('shoot', 1)

  self.in_water = false
  self.target_r = math.pi/2
  self.previous_in_water = false
  self.previous_vx, self.previous_vy = 0, 0
  self.last_in_water_time = an.time
  self.last_pressed_left, self.last_pressed_right = an.time, an.time
  self.last_gained_velocity_from_diving = an.time
  self.last_spawned_splash = an.time
  self.last_stopped_turning_left, self.last_stopped_turning_right = an.time, an.time
  self.last_stopped_turning_left_y, self.last_stopped_turning_right_y = self.y, self.y
  self.shoot_rs = 96

  self:stats()
  self:stats_set('hp', 10, 0, 10)
  self:stats_set('body_damage', 1, 0, 20)
  self:stats_set('projectile_damage', 1, 0, 20)
  self:stats_set('area_damage', 1, 0, 20)
  self:stats_set('recovery_speed', 7, 0, 20) -- how fast the player recovers after a bad landing
  self:stats_set('movement_speed', 7, 0, 20) -- base velocity under water
  self:stats_set('acceleration', 10, 0, 20) -- how much velocity the player gains on various triggers

  -- [3/(1.5*x) + 1] from 1 to 10; [10/x] from 10 to 20
  self.recovery_speed_to_recovery_time = {3, 2, 1.66, 1.5, 1.4, 1.33, 1.25, 1.166, 1.18, 1, 0.9, 0.833, 0.769, 0.714, 0.666, 0.625, 0.588, 0.55, 0.526, 0.5}
  self.recovery_speed_to_recovery_time[0] = 5
  -- modified [32*log(1.2*x)] from 1 to 20
  self.movement_speed_to_base_velocity = {6, 28, 40, 50, 57, 63, 68, 72, 76, 79.5, 82.5, 85.35, 88, 90, 92.5, 94.5, 96.5, 98.32, 100, 101.69}
  self.movement_speed_to_base_velocity[0] = 0
  self.base_v = self.movement_speed_to_base_velocity[self.stats.movement_speed.x]
  self.v = self.base_v
  self.max_v = 3*self.base_v
  -- [log(x)/15 + 0.025] from 1 to 20
  self.acceleration_to_dive_velocity_gain = {0.025, 0.0712, 0.098, 0.1174, 0.1323, 0.1444, 0.1547, 0.1636, 0.1714, 0.1785, 0.1848, 0.1906, 0.1959, 0.2009, 0.205, 0.21, 0.2138, 0.2179, 0.2213, 0.2247}
  self.acceleration_to_dive_velocity_gain[0] = 0
  -- [-0.025*x + 1] from 1 to 20
  self.acceleration_to_underwater_loss = {0.975, 0.95, 0.925, 0.9, 0.875, 0.85, 0.825, 0.8, 0.775, 0.75, 0.725, 0.7, 0.675, 0.65, 0.625, 0.6, 0.575, 0.55, 0.252, 0.5}
  self.acceleration_to_underwater_loss[0] = 1
  -- [log(x)/25] from 1 to 10; [0.005*(x-1) + 0.05] from 10 to 20
  self.acceleration_to_waving_velocity_gain = {0.0277, 0.0439, 0.0554, 0.0643, 0.0716, 0.0778, 0.0831, 0.0878, 0.0921, 0.1, 0.105, 0.11, 0.115, 0.12, 0.125, 0.13, 0.135, 0.14, 0.145, 0.15}
  self.acceleration_to_waving_velocity_gain[0] = 0

  self:timer_cooldown(0.3, function()
    return #self.players.arena:get_nearby_enemies(self.x, self.y, self.shoot_rs) > 0
  end, function()
    local target = self.players.arena:get_closest_enemy(self.x, self.y, self.shoot_rs)
    self:shoot(math.angle_to_point(self.x, self.y, target.x, target.y))
  end, nil, true, nil, 'shoot')
end
--}}}

--{{{ player movement + water
function player:update(dt)
  self.all_springs_x = self.springs.main.x*self.springs.shoot.x

  local splashed_down_this_frame = false
  local closest_water_spring = self.players.arena:get_closest_water_spring(self.x)
  if self.y > closest_water_spring.y then
    if self.recovering_from_bad_landing then goto recovering_from_bad_landing end
    local vx, vy = self:collider_get_velocity()
    local v = math.length(vx, vy)

    local time_elapsed_since_last_in_water = an.time - self.last_in_water_time -- use this to control added velocity, shouldn't add anything if has been in water recently at certain angles
    self.last_in_water_time = an.time
    self.in_water = true

    if not self.previous_in_water then
      local dot = math.dot(math.cos(self.target_r), math.sin(self.target_r), math.normalize(vx, vy))
      if dot < 0.5 then -- if velocity vector and target vector aren't aligned up to a point then it's coded as a bad landing, which enters the player into a recovery animation (no input while on it)
        self.recovering_from_bad_landing = true
        self.bad_landing_vx, self.bad_landing_vy = vx/2, vy/2
        local recovery_time = self.recovery_speed_to_recovery_time[self.stats.recovery_speed.x]
        local target_r = self.target_r + math.angle_to_horizontal(self.target_r)*math.pi/6
        self:timer_for(recovery_time, function() self.target_r = math.lerp_angle_dt(0.9, recovery_time, dt, self.target_r, target_r) end, nil, 'recovering_from_bad_landing_1')
        self:timer_tween(recovery_time*0.25, self, {bad_landing_vx = 0, bad_landing_vy = self.bad_landing_vy/2}, math.linear, function()
          local target_v = self.base_v
          self.v = 0
          self:timer_tween(recovery_time*0.75, self, {v = target_v}, math.linear, nil, 'recovering_from_bad_landing_3')
          self:timer_for(recovery_time*0.75, function()
            self.bad_landing_vx, self.bad_landing_vy = self.v*math.cos(target_r), self.v*math.sin(target_r)
          end, function() self.recovering_from_bad_landing = false end, 'recovering_from_bad_landing_4')
        end, 'recovering_from_bad_landing_2')
        self:timer_every(recovery_time/20, function() self.hidden = not self.hidden end, 20, nil, function() self.hidden = false end, 'recovering_from_bad_landing_5')

      else
        -- NOTE: decrease angle from 30 to lower here if a degenerate strategy around sideways skipping develops
        if time_elapsed_since_last_in_water < 0.8 and (math.deg(math.abs(math.angle_delta(0, self.target_r))) < 30 or math.deg(math.abs(math.angle_delta(math.pi, self.target_r))) < 30) then
          self.v = math.clamp(dot*self.v, self.base_v/4, self.max_v) -- prevent player from gaining velocity if he doing it sideways
        else
          if an.time - self.last_gained_velocity_from_diving > 0.15 then -- prevent too often repeated velocity gains when surfing/grinding
            self.last_gained_velocity_from_diving = an.time
            self.v = math.clamp(self.v + self.acceleration_to_dive_velocity_gain[self.stats.acceleration.x]*dot*dot*v, 0, self.max_v)
          end
        end
      end

      if an.time - self.last_spawned_splash > 0.15 then -- only do one splash and spawn one set of particles per water enter otherwise the effect will look wrong
        self.last_spawned_splash = an.time
        self.just_dived = true -- this is used to prevent other splash actions from acting on the water, like when the player is close to the edge, otherwise it cancels out the splash from the dive
        self:timer_after(0.3, function() self.just_dived = false end, 'just_dived')

        --[[
          Clean entry handles two cases: when the player enters the water aligned with its velocity vector, so a splash is made and mostly vertical particles are spawned to give that "bloop" effect.
          The second case is from when the player is surfing/grinding, which happens when the player is mostly at a horizontal angle and sort of skipping on the water.
          In this case particles are also spawned, but they're given the opposite direction to the player's velocity to give the movement a proper look.
        ]]--
        if dot >= 0.8 then
          local width = math.round(math.remap(dot, 0.8, 1, 3, 2), 0)
          local dot_f = math.remap(dot, 0, 1, 600, 240)
          local v_f = math.remap(v, 0, self.max_v, 0.5, 1)
          self.players.arena:splash(dot_f*v_f, self.x - self.w/2, width)
          local x, y = self.x, self.y
          local particle_velocity_multiplier = math.remap(v, 0, self.max_v, 0, 1)
          local particle_count = math.round(6*math.quad_in(math.remap(v, 0, self.max_v, 0, 1)), 0)
          local added_angle_direction = -math.sign(vx)
          local added_angle = math.remap(math.abs(vx), 0, self.max_v, 0, math.pi/4)
          local smallest_delta_to_target_r = math.min(math.deg(math.abs(math.angle_delta(0, self.target_r))), math.deg(math.abs(math.angle_delta(math.pi, self.target_r))))
          local added_angle_magnitude = 0
          -- only add to the final particle angle if .target_r is close to 0 or 180 (<30 degrees), for the cases where the player is surfing/grinding
          if smallest_delta_to_target_r <= 30 then added_angle_magnitude = math.remap(smallest_delta_to_target_r, 0, 30, 1, 0.25) end
          self:timer_after(0.1, function()
            for i = 1, particle_count do
              self:add(water_particle(x, y, {r = -math.pi/2 + an:random_float(-math.pi/32, math.pi/32) + added_angle_direction*added_angle*added_angle_magnitude,
                v = (added_angle_magnitude > 0 and 1.2 or 1)*particle_velocity_multiplier*an:random_float(100, 200)}))
            end
          end)
          if added_angle_magnitude > 0 then
            local added_angle = math.remap(math.abs(vx), 0, self.max_v, 0, math.pi/8)
            for i = 1, math.floor(particle_count/2) do
              self:add(water_particle(x, y, {r = -math.pi/2 + an:random_float(-math.pi/3, math.pi/3) - added_angle_direction*added_angle*added_angle_magnitude,
                v = particle_velocity_multiplier*an:random_float(100, 200)}))
            end
          end

        --[[
          Unclean entry handles two cases: the splash itself from an unclean entry, which should be bigger and have more particles than a clean entry.
          And then it also handles the case where the player has enough horizontal velocity that a wave should be created from this unclean entry, this is the "vx_01 > 0.25" conditional.
          When this happens, the splash is divided over time to create a wave effect, and particles also have some directionality instead of being angled randomly.
        --]]
        elseif dot < 0.8 then
          local x, y = self.x, self.y
          local dot_abs = math.abs(dot)
          local vx_01 = math.remap(math.abs(vx), 0, self.max_v, 0, 1)
          local v_f = math.remap(v, 0, self.max_v, 0.5, 1)
          local vx_direction = math.sign(vx)
          if vx_01 > 0.25 then
            local dot_f = math.remap(dot_abs*(1-vx_01), 0, 0.8, 600, 200)
            local width = math.round(vx_01*math.remap(dot_abs, 0, 0.8, 14, 6), 0)
            local spring_w = self.players.arena.water_spring_w
            local j = 0
            for i = 1, width do
              self:timer_after(0.04*(i-1), function()
                self.players.arena:splash(-dot_f*vx_01*v_f, self.x - self.w/2 + spring_w*j, 2)
                j = j + vx_direction
              end)
            end
            local particle_velocity_multiplier = math.remap(math.abs(vx), 0, self.max_v, 0.5, 2)
            local particle_count = math.round(14*math.quad_in(vx_01), 0)
            for i = 1, particle_count do
              self:add(water_particle(x, y, {r = (vx_direction == 1 and -math.pi/4 or -3*math.pi/4) + an:random_float(-math.pi/8, math.pi/8),
                v = particle_velocity_multiplier*an:random_float(100, 200)}))
            end
          end
          local width = math.round(math.remap(dot_abs, 0, 0.8, 9, 3), 0)
          local dot_f = math.remap(dot_abs, 0, 0.8, 400, 200)
          local v_f = math.remap(v, 0, self.max_v, 0.1, 1)
          self.players.arena:splash(dot_f*v_f, self.x - self.w/2, width)
          local particle_count = math.round(24*math.quad_in(math.remap(v, 0, self.max_v, 0, 1)), 0)
          for i = 1, particle_count do
            self:add(water_particle(x, y, {r = -math.pi/2 + an:random_float(-math.pi/3, math.pi/3), v = an:random_float(25, 200)}))
          end
        end
      end
    end

  --[[
    This handles the case where the player is getting out of the water.
    This creates a reverse splash with a small delay, and some vertical particles with a slightly bigger delay to make the effect look more realistic.
    The particles are also angled slightly towards the player's movement direction, to give a trail-like effect to his exit from the water.
  --]]
  else
    if self.recovering_from_bad_landing then goto recovering_from_bad_landing end
    local vx, vy = self:collider_get_velocity()
    local v = math.length(vx, vy)
    self.in_water = false
    if self.previous_in_water and vy < 0 and an.time - self.last_spawned_splash > 0.15 then -- only do one splash and spawn one set of particles per water exit
      local target_r = self.target_r
      local x, y = self.x, self.y
      local v_f = math.remap(math.abs(vy), 0, self.max_v, 0.25, 1)
      self:timer_after(0.05, function()
        self.last_spawned_splash = an.time
        local width = 3
        self.players.arena:splash(-250*v_f, self.x - self.w/2, width)
      end)
      self:timer_after(0.05 + math.remap(v_f, 0.25, 1, 0.01, 0.025), function()
        local particle_velocity_multiplier = math.remap(v, 0, self.max_v, 0.5, 1)
        local particle_count = math.round(10*math.quad_in(math.remap(v, 0, self.max_v, 0, 1)), 0)
        for i = 1, particle_count do
          self:add(water_particle(x, y, {r = -math.pi/2 + math.angle_delta(-math.pi/2, target_r) + an:random_float(-math.pi/32, math.pi/32),
            v = particle_velocity_multiplier*an:random_float(75, 150)}))
        end
      end)
    end
  end

  ::recovering_from_bad_landing:: -- recovering, so don't do any in/out of water stuff

  if self.in_water and not self.recovering_from_bad_landing then
    if self.v > self.base_v then
      local velocity_loss_percentage = self.acceleration_to_underwater_loss[self.stats.acceleration.x]*math.remap(self.v, self.base_v, self.max_v, 0.02, 0.1)
      self.v = self.v - velocity_loss_percentage*self.v*dt -- while in water, decrease velocity by 2-10% every second until it reaches .base_v, higher percentage the closer to .max_v it is
    end
  end

  if self.x < 0 then self:collider_set_position(an.w, self.y) end
  if self.x > an.w then self:collider_set_position(0, self.y) end

  self:collider_update_transform()
  local vx, vy = self:collider_get_velocity()
  self.turning_left, self.turning_right = false, false
  self.waving = false

  if not self.recovering_from_bad_landing then
    if an:is_pressed('left') then self.last_pressed_left = an.time end
    if an:is_pressed('right') then self.last_pressed_right = an.time end
    if an:is_down('left') then
      self.target_r = self.target_r - math.pi*dt
      self.turning_left = true
      if self.in_water and an.time - self.last_pressed_left < 0.32 and an.time - self.last_pressed_right > 0.1 then
        -- if has pressed left recently and has not pressed right too recently (to prevent spam), gain 3-15% velocity every second
        self.v = math.clamp(self.v + self.acceleration_to_waving_velocity_gain[self.stats.acceleration.x]*self.v*dt, 0, self.max_v)
        self.waving = true
      end
    end
    if an:is_down('right') then
      self.target_r = self.target_r + math.pi*dt
      self.turning_right = true
      if self.in_water and an.time - self.last_pressed_right < 0.32 and an.time - self.last_pressed_left > 0.1 then
        -- if has pressed right recently and has not pressed left too recently (to prevent spam), gain 3-15% velocity every second
        self.v = math.clamp(self.v + self.acceleration_to_waving_velocity_gain[self.stats.acceleration.x]*self.v*dt, 0, self.max_v)
        self.waving = true
      end
    end
    if self.in_water then
      self:collider_move_towards_angle(self.target_r, self.v)
    end
  end
  self:collider_rotate_towards_point(0.9, 0.1, dt, self.x + 20*math.cos(self.target_r), self.y + 20*math.sin(self.target_r))
  if self.recovering_from_bad_landing then self:collider_set_velocity(self.bad_landing_vx, self.bad_landing_vy) end

  --[[
    This handles the case where the player is close to the water's edge but under it.
    This is made up of two types of splashes: a weak, continuous one that is applied as long as the player is close to the edge.
    And a strong, discrete one that is applied only when the player turns while close to the edge. This second type of splash is a wave that works the same as the waves for an unclean entry.
  --]]
  if self.in_water and not self.recovering_from_bad_landing and not self.just_dived then
    if an:is_released('left') then
      self.last_stopped_turning_left = an.time
      self.last_stopped_turning_left_y = self.y
    end
    if an:is_released('right') then
      self.last_stopped_turning_right = an.time
      self.last_stopped_turning_right_y = self.y
    end

    local dy = math.abs(self.y - closest_water_spring.y)
    local underwave_activation_range = 32
    if dy < underwave_activation_range then
      local vx, vy = self:collider_get_velocity()
      local v = math.length(vx, vy)
      local distance_multiplier = math.remap(dy, 0, underwave_activation_range, 1, 0)
      local velocity_multiplier = 2*math.quad_in(math.remap(v, 0, self.max_v, 0, 1))
      self.players.arena:splash(-40*distance_multiplier*velocity_multiplier, self.x - self.w/2, 1)
      if math.sign(vx) == 1 then
        if math.abs(self.last_stopped_turning_left_y - closest_water_spring.y) < underwave_activation_range then
          if self.turning_right and an.time - self.last_stopped_turning_left < 0.15 then
            local width = math.round(math.remap(distance_multiplier, 0, 1, 16, 4), 0)
            local spring_w = self.players.arena.water_spring_w
            local j = 0
            for i = 1, width do
              self:timer_after(0.04*(i-1), function()
                self.players.arena:splash(-75*distance_multiplier*velocity_multiplier*(velocity_multiplier > 1.6 and (velocity_multiplier - 0.4) or 1), self.x - self.w/2 + spring_w*j, 1)
                j = j + math.sign(vx)
              end)
            end
          end
        end
      else
        if math.abs(self.last_stopped_turning_right_y - closest_water_spring.y) < underwave_activation_range then
          if self.turning_left and an.time - self.last_stopped_turning_right < 0.15 then
            local width = math.round(math.remap(distance_multiplier, 0, 1, 16, 4), 0)
            local spring_w = self.players.arena.water_spring_w
            local j = 0
            for i = 1, width do
              self:timer_after(0.04*(i-1), function()
                self.players.arena:splash(-75*distance_multiplier*velocity_multiplier*(velocity_multiplier > 1.6 and (velocity_multiplier - 0.4) or 1), self.x - self.w/2 + spring_w*j, 1)
                j = j + math.sign(vx)
              end)
            end
          end
        end
      end
    end
  end

  self.previous_in_water = self.in_water
  self.previous_vx, self.previous_vy = self:collider_get_velocity()
--}}}

--{{{ player 2
  if self.hidden then return end
  game:push(self.x, self.y, self.r)
    game:rectangle(self.x, self.y, self.w, self.h, self.rx, self.rx, self.flashing and flash_color or self.color)
  game:pop()
  game:circle(self.x + self.w*math.cos(self.target_r), self.y + self.w*math.sin(self.target_r), 2, self.flashing and flash_color or self.color)
  show_hp_bar(self, self.color)
end

function player:shoot(r)
  if self.in_water then return end
  local r, d = r or self.r, self.w
  an:spring_shake(2, r)
  self:spring_pull('shoot', 0.5)
  self:flash(0.2)
  self.players.arena:add(hit_circle(self.x + 0.8*d*math.cos(r), self.y + 0.8*d*math.sin(r), {duration = 0.175, rs = 9}))
  for i = 1, 3 do
    self.players.arena:add(hit_particle(self.x + 0.8*d*math.cos(r), self.y + 0.8*d*math.sin(r), {r = r + an:random_float(-math.pi/3, math.pi/3), w = 8,
      v = an:random_float(25, 125)}):change_color(0.66, self.color))
  end
  local p = projectile(self.x + 1.6*d*math.cos(r), self.y + 1.6*d*math.sin(r), {damage = self.stats.projectile_damage.x, r = r, v = 250, color = self.color, mods = self.projectile_mods})
  self.players.arena.projectiles:add(p)
end

function player:hit_enemy(enemy)
  if enemy.just_hit_by_player then return end
  enemy.just_hit_by_player = true
  enemy:timer_after(0.2, function() enemy.just_hit_by_player = false end, 'just_hit_by_player')

  local x, y = (self.x + enemy.x)/2, (self.y + enemy.y)/2
  local v = math.length(self:collider_get_velocity())
  enemy:push(math.remap(v, 50, 200, 10, 40), self.target_r)
  enemy:hit_damage(self.stats.body_damage.x, x, y)
  enemy:spring_pull('main', 0.5)

  self:spring_pull('main', 0.5)
  self.players.arena:add(hit_effect(x, y, {s = 1.2}))
  for i = 1, 2 do self.players.arena:add(hit_particle(x, y):change_color(0.5, self.color)) end
  for i = 1, 2 do self.players.arena:add(hit_particle(x, y):change_color(0.5, enemy.color)) end
end

function player:hit_solid(solid, x, y, nx, ny)
  local vx, vy = math.bounce(self.previous_vx, self.previous_vy, nx, ny)
  self.target_r = math.angle(vx, vy)
  self:collider_set_velocity(vx, vy)
end
--}}}
