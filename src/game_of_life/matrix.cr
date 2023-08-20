struct GameOfLife::Matrix
  @matrix = Slice(Float32).new(4*4, 0_f32)

  delegate to_unsafe, to: @matrix

  def initialize
  end

  def self.identity
    matrix = Matrix.new

    matrix[0, 0] = 1.0_f32
    matrix[1, 1] = 1.0_f32
    matrix[2, 2] = 1.0_f32
    matrix[3, 3] = 1.0_f32

    matrix
  end

  def index(row, column)
    column * 4 + row
  end

  def [](row, column)
    @matrix[index(row, column)]
  end

  def []=(row, column, value : Float32)
    @matrix[index(row, column)] = value
  end

  def *(other : self)
    result = Matrix.new

    4.times do |i|
      4.times do |j|
        sum = 0.0_f32
        4.times do |k|
          sum += self[i, k] * other[k, j]
        end
        result[i, j] = sum
      end
    end

    result
  end

  def self.translation(x : Float32, y : Float32)
    matrix = Matrix.identity

    matrix[0, 3] = x
    matrix[1, 3] = y

    matrix
  end

  def self.orthographic(width : Float32, height : Float32)
    aspect = width / height

    matrix = Matrix.new

    matrix[0, 0] = 1.0_f32 / aspect
    matrix[1, 1] = 1.0_f32
    matrix[3, 3] = 1.0_f32

    matrix
  end
end
