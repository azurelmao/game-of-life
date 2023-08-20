class GameOfLife::CellPlane
  record Pos, x : Int32, y : Int32
  record Cell
  getter cells = Hash(Pos, Cell).new

  def get_cell(x, y)
    @cells[Pos.new(x, y)]?
  end

  def set_cell(x, y)
    pos = Pos.new(x, y)
    if @cells.has_key? pos
      @cells.delete(pos)
    else
      @cells[pos] = Cell.new
    end
  end

  def step
    new_cells = Hash(Pos, Cell).new

    @cells.each do |(pos, cell)|
      live_neighbors = 0

      (-1..1).each do |x|
        (-1..1).each do |y|
          next if x == y == 0
          if neighbor = get_cell(pos.x + x, pos.y + y)
            live_neighbors += 1
          else
            live_neighbors2 = 0
            (-1..1).each do |xn|
              (-1..1).each do |yn|
                next if xn == yn == 0
                live_neighbors2 += 1 if get_cell(pos.x + x + xn, pos.y + y + yn)
              end
            end
            new_cells[Pos.new(pos.x + x, pos.y + y)] = Cell.new if live_neighbors2 == 3
          end
        end
      end
      new_cells[Pos.new(pos.x, pos.y)] = Cell.new if live_neighbors == 2 || live_neighbors == 3
    end

    @cells = new_cells
    @cells
  end
end
