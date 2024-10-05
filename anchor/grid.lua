--[[
  Module responsible for turning the object into a grid that can hold arbitrary data.
  Examples:
    object():grid(10, 10, 0)                -> creates a new 10 by 10 grid with all values zeroed
    object():grid(3, 2, {1, 2, 3, 4, 5, 6}) -> creates a new 3 by 2 grid with values 1, 2, 3 in the 1st row and 3, 4, 5 in the 2nd
    object():grid(10, 10, 'assets/map.png', {{0, 0, 0, 1}, {1, 1, 1, 0}, {1, 0, 0, 2}, {0, 1, 0, 3}})
  The last example loads a pixel map from the assets folder. This map should have the same size as the grid its attached to.
  The last argument is a table containing the RGB colors of each pixel in the map, and their value as a number in the grid.
  So, in this case, black would be 1, white would be 0, red would be 2 and green would be 3.
]]--
grid = class:class_new()
function grid:grid(w, h, v, u)
  self.tags.grid = true
  self.grid_w = w
  self.grid_h = h
  local v = v or 0

  self.grid = {}
  if type(v) == 'table' then
    for j = 1, h do
      for i = 1, w do
        self.grid[w*(j-1) + i] = v[w*(j-1) + i]
      end
    end
  elseif type(v) == 'string' then
    local map = love.image.newImageData(v)
    w, h = map:getDimensions()
    local error_1 = v .. " has unmatched colors. "
    local error_2 = "The last argument of a grid's init function must have values for all colors that appear on the map image."
    if not u then error(error_1 .. error_2) end
    for y = 1, h do
      for x = 1, w do
        r, g, b, a = map:getPixel(x-1, y-1)
        local index = array.index(u, function(v) return v[1] == r and v[2] == g and v[3] == b end)
        if index then
          self.grid[w*(y-1) + x] = u[index][4]
        else
          error(error_1 .. "(#{r}, #{g}, #{b}):n" .. error_2)
        end
      end
    end
  else
    for j = 1, h do
      for i = 1, w do
        self.grid[w*(j-1) + i] = v
      end
    end
  end
  return self
end

--[[
  Creates a copy of the grid.
  This is the same as "object():grid(self.grid_w, self.grid_h, self.grid)"
  Example:
    grid = object():grid(10, 10, 0)
    grid_2 = grid:grid_copy()
    grid:grid_set(1, 1, 1)
    print grid_2:grid_get(1, 1) -> prints 0
]]--
function grid:grid_copy()
  return object():grid(self.grid_w, self.grid_h, self.grid)
end

--[[
  Draws the grid based on the values passed to grid_set_dimensions. This is mostly for debug purposes.
  If you want to draw the grid in your game with more details just copy the contents of this function and go from there.
  Example:
    grid = object():grid(10, 10, 0)
    grid:grid_set_dimensions(an.w/2, an.h/2, 24, 24)
    grid:grid_draw(game, an.colors.white[0], 1)
]]--
function grid:grid_draw(layer, color, line_width)
  for i = 1, self.grid_w do
    for j = 1, self.grid_h do
      layer:rectangle(self.x1 + self.cell_w/2 + (i-1)*self.cell_w, self.y1 + self.cell_h/2 + (j-1)*self.cell_h, self.cell_w, self.cell_h, 0, 0, color, line_width)
    end
  end
end

--[[
  Generates a maze on this grid according to the given algorithm.
  The maze generation algorithm used is "Growing Tree" from https://weblog.jamisbuck.org/2011/1/27/maze-generation-growing-tree-algorithm.
  The values passed in are based on the Growing Tree's cell choice policy. The possible choices are:
    'newest' (recursive backtracking)
    'random' (prim)
    'oldest'
    'middle'
  Two additional values can be passed in, the first deciding how much the first policy affects the maze, and the second being the second policy.
  For instance, "'newest', 80, 'oldest'" will apply the 'newest' policy to 80% of cells, and the 'oldest' policy to 20% of cells.
  The initial grid should be zerod and after it is altered by this function each cell will contain a table with the following properties:
    x, y - the cell's x, y position in world units if grid_set_dimensions was previously set
    i, j - the cell's x, y position in grid units
    connections - a table with fields 'up', 'right', 'down' and 'left', each being true or false to signify if there's an opening to that neighbor
    walls - a table with fields 'up', 'right', 'down' and 'left', each being true or false to signify if there's a wall to that neighbor
      ("connections" and "walls" are opposites, if 'right' is true in one, 'right' should be false in the other and so on)
    distance_to_start - this cells' distance to the starting cell as an integer
  TODO: examples
--]]
function grid:grid_generate_maze(a, b, c)
  for i = 1, self.grid_w do
    for j = 1, self.grid_h do
      local x, y = self:grid_get_cell_position(i, j)
      self:grid_set(i, j, {x = x, y = y, i = i, j = j, connections = {}, walls = {up = true, right = true, down = true, left = true},
        distance_to_start = 0, visited = false})
    end
  end

  local all_cells = {}
  for _, _, cell in self:grid_pairs() do table.insert(all_cells, cell) end
  array.shuffle(all_cells)

  local cells = {}
  local cell = array.remove_random(all_cells)
  cell.visited = true
  table.insert(cells, cell)

  local get_index = function(a)
    if a == 'newest' then return #cells
    elseif a == 'oldest' then return 1
    elseif a == 'random' then return an:random_int(1, #cells)
    elseif a == 'middle' then return math.clamp(math.floor(#cells/2), 1, #cells)
    end
  end

  repeat
    local i = 0
    if not b and not c then
      i = get_index(a)
    elseif a and b and c then
      if an:random_bool(b) then
        i = get_index(a)
      else
        i = get_index(c)
      end
    end

    local cell = cells[i]
    local direction_opposites = {up = 'down', down = 'up', left = 'right', right = 'left'}
    local directions = {{x = 0, y = -1, name = 'up'}, {x = 1, y = 0, name = 'right'}, {x = 0, y = 1, name = 'down'}, {x = -1, y = 0, name = 'left'}}
    for _, direction in ipairs(array.shuffle(directions)) do
      local nx, ny = cell.i + direction.x, cell.j + direction.y
      local neighbor = self:grid_get(nx, ny)
      if neighbor and not neighbor.visited then
        cell.connections[direction.name] = true
        cell.walls[direction.name] = false
        neighbor.connections[direction_opposites[direction.name]] = true
        neighbor.walls[direction_opposites[direction.name]] = false
        neighbor.distance_to_start = cell.distance_to_start + 1
        i = nil
        neighbor.visited = true
        table.insert(cells, neighbor)
        break
      end
    end
    if i then table.remove(cells, i) end
  until #cells <= 0
end

--[[
  Returns the value at the given index, nil if the value isn't set or the indexes are out of bounds.
  To make things easier on yourself, consider making the default "no value" value 0 instead of nil,
  otherwise you won't be able to tell when the operation failed due to out of bounds vs. value not being set.
  Examples:
    self:grid(3, 2, {1, 2, 3, 4, 5, 6})
    self:grid_get()     -> nil
    self:grid_get(1, 1) -> 1
    self:grid_get(1, 2) -> 4
    self:grid_get(3, 2) -> 6
    self:grid_get(4, 4) -> nil due to out of bounds
]]--
function grid:grid_get(x, y)
  if not self:grid_is_outside_bounds(x, y) then
    return self.grid[self.grid_w*(y-1) + x]
  end
end

--[[
  Returns the position of the given cell, assuming self.x, self.y, self.cell_w and self.cell_h are set.
  Before using this function you must set the grid's dimensions using "grid_set_dimensions".
  Example:
    grid = object():grid(10, 10)
    grid:grid_set_dimensions(an.w/2, an.h/2, 20, 20)
    grid:grid_get_cell_position(1, 1 -> an.w/2 - 100 + 10, an.h/2 - 100 + 10)
]]--
function grid:grid_get_cell_position(x, y)
  local total_w, total_h = self.grid_w*self.cell_w, self.grid_h*self.cell_h
  local x1, y1 = self.x - total_w/2, self.y - total_h/2
  return x1 + self.cell_w/2 + (x-1)*self.cell_w, y1 + self.cell_h/2 + (y-1)*self.cell_h
end

--[[
  Internal function that checks if an index is or isn't out of bounds.
  As mentioned in the comments of grid_get, make the default "no value" value 0 instead of nil in your game.
  If you don't do this, then whenever a grid_get/set function returns nil, you won't know if it failed or not.
]]--
function grid:grid_is_outside_bounds(x, y)
  if x > self.grid_w then return true end
  if x < 1 then return true end
  if y > self.grid_h then return true end
  if y < 1 then return true end
end

--[[
  Returns an iterator over all the grid's values in left-right top-bottom order.
  Example:
    local grid = object():grid(10, 10)
    for i, j, v in grid:grid_pairs() do
      print(i, j, v)
    end
  The example above will print 1 to 10 on both axes as well as the values on each specific cell (in this example they're all zero).
--]]
function grid:grid_pairs()
  local i, j = 0, 1
  return function()
    i = i + 1
    if i > self.grid_w then i = 1; j = j + 1 end
    if i <= self.grid_w and j <= self.grid_h then
      return i, j, self:grid_get(i, j)
    end
  end
end

--[[
  Sets the value on the given grid position and returns it if it was set successfully.
  Examples:
    self:grid(10, 10, 0)
    self:grid_set()                     -> nil
    self:grid_set(1, 1)                 -> nil
    self:grid_set(2, 2, 1)              -> 1
    self:grid_set(4, 8, function() end) -> returns the anonymous function passed in
    self:grid_set(11, 1, true)          -> nil due to out of bounds, so nothing is changed
]]--
function grid:grid_set(x, y, v)
  if not self:grid_is_outside_bounds(x, y) then
    self.grid[self.grid_w*(y-1) + x] = v
    return v
  end
end

--[[
  Sets the value of all cells on the grind.
  TODO: examples
--]]
function grid:grid_set_all(f)
  for j = 1, self.grid_h do
    for i = 1, self.grid_w do
      self:grid_set(i, j, f(i, j))
    end
  end
end

--[[
  Sets the grids dimensions. This sets the following attributes:
    self.x, self.y             - the grid's center position in world coordinates
    self.cell_w, self.cell_h   - the width and height of each cell
    self.x1, self.y1           - the grid's top-left corner
    self.x2, self.y2           - the grid's bottom-right corner
    self.w, self.h             - the grid's total size in world units
  The first 4 attributes should be passed in, the latter 6 are calculated automatically.
]]--
function grid:grid_set_dimensions(x, y, cell_w, cell_h)
  self.x, self.y = x, y
  self.cell_w, self.cell_h = cell_w, cell_h
  self.w, self.h = self.grid_w*self.cell_w, self.grid_h*self.cell_h
  self.x1, self.y1 = self.x - self.w/2, self.y - self.h/2
  self.x2, self.y2 = self.x + self.w/2, self.y + self.h/2
end

--[[
  Returns a string that represents the grid's state.
]]--
function grid:grid_tostring()
  local s = ''
  for j = 1, self.grid_h do
    s = s .. '['
    for i = 1, self.grid_w do
      s = s .. self:grid_get(i, j) .. ', '
    end
    s = s:sub(1, -3) .. ']\n'
  end
  return s
end
