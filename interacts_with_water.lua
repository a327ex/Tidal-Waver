--[[
  Any objects that aren't the player interact with the water in the same way.
  The player's code for water interaction needs to be more specific because its what the player is controlling, and thus both visual and gameplay details matter more.
  For enemies, projectiles and other objects, interaction with water has less fidelity/resolution and so it can be roughly the same, while also having less edge cases and less complexity.
--]]
interacts_with_water = class:class_new()
function interacts_with_water:interacts_with_water(water_interaction_multiplier)
  self.tags.interacts_with_water = true
  self.in_water = false
  self.previous_in_water = false
  self.last_spawned_splash = an.time
  self.creation_time = an.time
  self.water_interaction_multiplier = water_interaction_multiplier or 1
  return self
end

function interacts_with_water:interacts_with_water_update(dt)
  local arena
  if self:is('enemy') then arena = self.enemies.arena
  elseif self:is('projectile') then arena = self.projectiles.arena end

  local area = self.w*self.h
  local splashed_down_this_frame = false
  local closest_water_spring = arena:get_closest_water_spring(self.x)
  local vx, vy = self:collider_get_velocity()
  local v = math.length(vx, vy)
  local r = self:collider_get_angle()
  local v_r = math.angle(vx, vy)

  if self.y > closest_water_spring.y then
    self.in_water = true
    if not self.previous_in_water then
      if an.time - self.last_spawned_splash > 0.5 or an.time - self.creation_time <= 0.5 then -- second condition for projectiles, since they're often near water right after being created
        self.last_spawned_splash = an.time
        local dot = math.dot(math.cos(r), math.sin(r), math.normalize(vx, vy))
        local v_f = math.clamp(math.remap(v, 0, self.base_v, 0.5, 1), 0.5, 3)
        local dot_f = math.remap(dot, 0, 1, 2, 0.5)
        arena:splash(1.5*area*v_f*dot_f*self.water_interaction_multiplier, self.x - self.w/2, 3)
        local particle_count = dot_f*math.round(self.water_interaction_multiplier*2*math.remap(v, 0, self.base_v, 0, 1), 0)
        local particle_velocity_multiplier = math.remap(v, self.base_v, 8*self.base_v, 0.25, 1)
        for i = 1, particle_count do
          self:add(water_particle(self.x, self.y, {r = -math.pi/2 + an:random_float(-math.pi/3, math.pi/3), v = particle_velocity_multiplier*an:random_float(25, 200)}))
        end
      end
    end

  else
    self.in_water = false
    if self.previous_in_water and vy < 0 and (an.time - self.last_spawned_splash > 0.5 or an.time - self.creation_time <= 0.5) then
      self.last_spawned_splash = an.time
      local x, y = self.x, self.y
      local v_f = math.clamp(math.remap(v, 0, self.base_v, 0.5, 1), 0.5, 3)
      self:timer_after(0.05, function()
        arena:splash(-2*area*v_f*self.water_interaction_multiplier, self.x - self.w/2, 3)
      end)
      self:timer_after(0.05 + math.remap(v_f, 0.5, 1, 0.01, 0.025), function()
        local particle_velocity_multiplier = math.remap(v, 0, 8*self.base_v, 0.5, 1)
        local particle_count = math.round(self.water_interaction_multiplier*3*math.remap(v, 0, self.base_v, 0, 1), 0)
        for i = 1, particle_count do
          self:add(water_particle(x, y, {r = -math.pi/2 + math.angle_delta(-math.pi/2, v_r) + an:random_float(-math.pi/32, math.pi/32),
            v = particle_velocity_multiplier*an:random_float(75, 150)}))
        end
      end)
    end
  end

  self.previous_in_water = self.in_water
end
object:class_add(interacts_with_water)
