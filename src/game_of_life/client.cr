require "espresso"
require "opengl"

class GameOfLife::Client
  TEXTURE_CURSOR = read_texture("resources/cursor/cursor.png")

  VERTEX_CELLS   = read_shader("resources/cell/vertex.glsl")
  FRAGMENT_CELLS = read_shader("resources/cell/fragment.glsl")

  VERTEX_CURSOR   = read_shader("resources/cursor/vertex.glsl")
  FRAGMENT_CURSOR = read_shader("resources/cursor/fragment.glsl")

  macro read_shader(path)
    {%
      source_path = env("GML_SOURCE_PATH")
      raise "Environment variable GML_SOURCE_PATH has to be defined!" unless source_path
    %}
    {{read_file(source_path + path)}}
  end

  macro read_texture(path)
    {%
      source_path = env("GML_SOURCE_PATH")
      raise "Environment variable GML_SOURCE_PATH has to be defined!" unless source_path
    %}
    begin
      bytes = {{read_file(source_path + path)}}.to_slice
      io = IO::Memory.new(bytes)
      texture = StumpyPNG.read(io)
      width, height = texture.width, texture.height
      texture_flipped = StumpyPNG::Canvas.new(width, height)
      width.times do |x|
        height.times do |y|
          texture_flipped[x, y] = texture[x, height - 1 - y]
        end
      end
      texture_flipped
    end
  end

  @window : Espresso::Window
  MAX_TICK_RATE = 500
  MIN_TICK_RATE =   1
  @max_zoom : Float32
  @min_zoom : Float32
  @zoom_level : Float32
  @view_position_x = 0.0_f32
  @view_position_y = 0.0_f32
  @prev_mouse_x = 0.0_f32
  @prev_mouse_y = 0.0_f32
  @prev_mouse_state = Espresso::ButtonState::Released
  @timer = Timer.new(500)
  @menu_open = false
  @paused = false

  def initialize
    Espresso.init
    @window = Espresso::Window.new(800, 800, "Conway's Game of Life")
    @window.current!

    @max_zoom = @window.framebuffer_size.height.to_f32 / 20.0_f32
    @min_zoom = 1.0_f32
    @zoom_level = @max_zoom

    # Keyboard logic
    @window.keyboard.on_key do |event|
      key = event.key
      pressed = event.pressed?

      if key.q? && pressed
        @window.closing = true
      elsif !@menu_open && key.space? && pressed
        @paused = !@paused
      elsif key.escape? && pressed
        @menu_open = !@menu_open
      end
    end
  end

  def finalize
    @window.destroy!
    Espresso.terminate
  end

  CELL_MODEL = Float32[
    # |   x    |   y    |   u    |   v    |
    0.0_f32, 1.0_f32, 0.0_f32, 0.0_f32,
    0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32, # first triangle
    1.0_f32, 0.0_f32, 1.0_f32, 1.0_f32,

    1.0_f32, 0.0_f32, 1.0_f32, 1.0_f32,
    1.0_f32, 1.0_f32, 1.0_f32, 0.0_f32, # second triangle
    0.0_f32, 1.0_f32, 0.0_f32, 0.0_f32,
  ]

  def generate_cursor_mesh(cell_x : Float32, cell_y : Float32)
    mesh = Array(Float32).new

    CELL_MODEL.each_with_index do |value, index|
      case index % 4
      when 0    then mesh << value + cell_x
      when 1    then mesh << value + cell_y
      when 2, 3 then mesh << value
      end
    end

    mesh
  end

  def generate_cells_mesh(cells)
    mesh = Array(Float32).new

    cells.each_key do |pos|
      CELL_MODEL.each_with_index do |value, index|
        case index % 4
        when 0 then mesh << value + pos.x.to_f32
        when 1 then mesh << value + pos.y.to_f32
        end
      end
    end

    mesh
  end

  def update_buffer(mesh)
    LibGL.buffer_data(LibGL::BufferTargetARB::ArrayBuffer, mesh.size * sizeof(Float32), mesh.to_unsafe, LibGL::BufferUsageARB::DynamicDraw)
  end

  def zoom_level_normalized
    @zoom_level / (@window.framebuffer_size.height.to_f32 / 2.0_f32)
  end

  def update_view_position(mouse_x : Float32, mouse_y : Float32)
    window_size = @window.framebuffer_size
    window_width = window_size.width.to_f32
    window_height = window_size.height.to_f32

    window_half_width = window_width / 2.0_f32
    window_half_height = window_height / 2.0_f32

    cell_width = window_half_width * zoom_level_normalized * (window_height / window_width)
    cell_height = window_half_height * zoom_level_normalized

    if @prev_mouse_state.released?
      @prev_mouse_x = mouse_x
      @prev_mouse_y = mouse_y
    end

    offset_x = mouse_x - @prev_mouse_x
    offset_y = @prev_mouse_y - mouse_y

    @prev_mouse_x = mouse_x
    @prev_mouse_y = mouse_y

    x = offset_x / cell_width
    y = offset_y / cell_height

    @view_position_x += x
    @view_position_y += y
  end

  def cursor_cell_position
    window_size = @window.framebuffer_size
    window_width = window_size.width.to_f32
    window_height = window_size.height.to_f32

    window_half_width = window_width / 2.0_f32
    window_half_height = window_height / 2.0_f32

    cell_width = window_half_width * zoom_level_normalized * (window_height / window_width)
    cell_height = window_half_height * zoom_level_normalized

    mouse_pos = @window.mouse.position
    mouse_x = mouse_pos.x.to_f32
    mouse_y = mouse_pos.y.to_f32

    offset_x = mouse_x - window_half_width
    offset_y = window_half_height - mouse_y

    x = offset_x / cell_width - @view_position_x
    y = offset_y / cell_height - @view_position_y

    x = x.floor.to_i
    y = y.floor.to_i

    return x, y
  end

  def use_programs(*shader_programs, &)
    shader_programs.each do |shader_program|
      LibGL.use_program(shader_program)
      yield shader_program
    end
  end

  def start
    cell_plane = CellPlane.new


    vertex_cells = OpenGL.shader(VERTEX_CELLS.to_unsafe, LibGL::ShaderType::VertexShader)
    fragment_cells = OpenGL.shader(FRAGMENT_CELLS.to_unsafe, LibGL::ShaderType::FragmentShader)
    program_cells = OpenGL.shader_program(vertex_cells, fragment_cells)

    vertex_cursor = OpenGL.shader(VERTEX_CURSOR.to_unsafe, LibGL::ShaderType::VertexShader)
    fragment_cursor = OpenGL.shader(FRAGMENT_CURSOR.to_unsafe, LibGL::ShaderType::FragmentShader)
    program_cursor = OpenGL.shader_program(vertex_cursor, fragment_cursor)

    texture_cursor = OpenGL.texture(TEXTURE_CURSOR)
    LibGL.active_texture(LibGL::TextureUnit::Texture0)
    LibGL.bind_texture(LibGL::TextureTarget::Texture2D, texture_cursor)
    OpenGL.set_int(program_cursor, "Texture", 0)

    projection = Matrix.orthographic(@window.size.width.to_f32, @window.size.height.to_f32)
    view = Matrix.translation(@view_position_x * zoom_level_normalized, @view_position_y * zoom_level_normalized)

    # Uniforms
    use_programs(program_cells, program_cursor) do |shader_program|
      OpenGL.set_float(shader_program, "ZoomLevel", zoom_level_normalized)
      OpenGL.set_matrix(shader_program, "Projection", projection)
      OpenGL.set_matrix(shader_program, "View", view)
    end

    # Cells buffer
    begin
      LibGL.gen_vertex_arrays(1, out vao_cells)
      LibGL.bind_vertex_array(vao_cells)

      LibGL.gen_buffers(1, out vbo_cells)
      LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cells)
      update_buffer(generate_cells_mesh(cell_plane.cells))

      LibGL.vertex_attrib_pointer(0, 2, LibGL::VertexAttribPointerType::Float, LibGL::Boolean::False, 2 * sizeof(Float32), Pointer(Void).new 0)
      LibGL.enable_vertex_attrib_array(0)
    end

    # Cursor buffer
    begin
      LibGL.gen_vertex_arrays(1, out vao_cursor)
      LibGL.bind_vertex_array(vao_cursor)

      LibGL.gen_buffers(1, out vbo_cursor)
      LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cursor)
      cursor_pos = cursor_cell_position
      cursor_x = cursor_pos[0].to_f32
      cursor_y = cursor_pos[1].to_f32
      update_buffer(generate_cursor_mesh(cursor_x, cursor_y))

      LibGL.vertex_attrib_pointer(0, 2, LibGL::VertexAttribPointerType::Float, LibGL::Boolean::False, 4 * sizeof(Float32), Pointer(Void).new 0)
      LibGL.enable_vertex_attrib_array(0)

      LibGL.vertex_attrib_pointer(1, 2, LibGL::VertexAttribPointerType::Float, LibGL::Boolean::False, 4 * sizeof(Float32), Pointer(Void).new 2 * sizeof(Float32))
      LibGL.enable_vertex_attrib_array(1)
    end

    # Mouse scroll logic / zooming
    @window.mouse.on_scroll do |event|
      if @window.keyboard.key? Espresso::Key::LeftControl
        unit = event.y.to_i
        unit *= 10 if @timer.tick_rate > 10
        @timer.tick_rate = (@timer.tick_rate - unit).clamp(MIN_TICK_RATE, MAX_TICK_RATE)
      else
        @zoom_level = (@zoom_level + event.y.to_f32).clamp(@min_zoom, @max_zoom)

        mouse_pos = @window.mouse.position
        mouse_x = mouse_pos.x.to_f32
        mouse_y = mouse_pos.y.to_f32

        update_view_position(mouse_x, mouse_y)
        view = Matrix.translation(@view_position_x * zoom_level_normalized, @view_position_y * zoom_level_normalized)

        use_programs(program_cells, program_cursor) do |shader_program|
          OpenGL.set_float(shader_program, "ZoomLevel", zoom_level_normalized)
          OpenGL.set_matrix(shader_program, "View", view)
        end

        cursor_pos = cursor_cell_position
        cursor_x = cursor_pos[0].to_f32
        cursor_y = cursor_pos[1].to_f32

        LibGL.bind_vertex_array(vao_cursor)
        LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cursor)
        update_buffer(generate_cursor_mesh(cursor_x, cursor_y))
      end
    end

    # Framebuffer logic
    @window.on_resize do |event|
      @max_zoom = event.height.to_f32 / 20.0_f32

      LibGL.viewport(0, 0, event.width, event.height)
      projection = Matrix.orthographic(@window.size.width.to_f32, @window.size.height.to_f32)

      use_programs(program_cells, program_cursor) do |shader_program|
        OpenGL.set_float(shader_program, "ZoomLevel", zoom_level_normalized)
        OpenGL.set_matrix(shader_program, "Projection", projection)
      end

      cursor_pos = cursor_cell_position
      cursor_x = cursor_pos[0].to_f32
      cursor_y = cursor_pos[1].to_f32

      LibGL.bind_vertex_array(vao_cursor)
      LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cursor)
      update_buffer(generate_cursor_mesh(cursor_x, cursor_y))
    end

    # Mouse button logic
    @window.mouse.on_button do |event|
      if event.right? && event.pressed?
        x, y = cursor_cell_position
        cell_plane.set_cell(x, y)
        LibGL.bind_vertex_array(vao_cells)
        LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cells)
        update_buffer(generate_cells_mesh(cell_plane.cells))
      end
    end

    # Mouse dragging logic / cursor
    @window.mouse.on_move do |event|
      if @window.mouse.left?
        mouse_x = event.x.to_f32
        mouse_y = event.y.to_f32

        update_view_position(mouse_x, mouse_y)
        view = Matrix.translation(@view_position_x * zoom_level_normalized, @view_position_y * zoom_level_normalized)

        use_programs(program_cells, program_cursor) do |shader_program|
          OpenGL.set_matrix(shader_program, "View", view)
        end
      end

      cursor_pos = cursor_cell_position
      cursor_x = cursor_pos[0].to_f32
      cursor_y = cursor_pos[1].to_f32

      LibGL.bind_vertex_array(vao_cursor)
      LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cursor)
      update_buffer(generate_cursor_mesh(cursor_x, cursor_y))

      @prev_mouse_state = @window.mouse.left
    end

    LibGL.enable(LibGL::EnableCap::CullFace)
    LibGL.enable(LibGL::EnableCap::Blend)
    LibGL.blend_func(LibGL::BlendingFactor::SrcAlpha, LibGL::BlendingFactor::OneMinusSrcAlpha)

    # Render loop
    delta_time = 0.0
    until @window.closing?
      start_time = Time.utc

      LibGL.clear_color(0.0, 0.0, 0.0, 1.0)
      LibGL.clear(LibGL::ClearBufferMask::ColorBuffer | LibGL::ClearBufferMask::DepthBuffer)

      @timer.update
      @timer.elapsed_ticks.times do
        LibGL.bind_vertex_array(vao_cells)
        LibGL.bind_buffer(LibGL::BufferTargetARB::ArrayBuffer, vbo_cells)
        update_buffer(generate_cells_mesh(cell_plane.step)) unless @paused || @menu_open
      end

      LibGL.use_program(program_cells)
      LibGL.bind_vertex_array(vao_cells)
      LibGL.draw_arrays(LibGL::PrimitiveType::Triangles, 0, cell_plane.cells.size * 6)

      LibGL.use_program(program_cursor)
      LibGL.bind_vertex_array(vao_cursor)
      LibGL.draw_arrays(LibGL::PrimitiveType::Triangles, 0, 6)

      @window.swap_buffers
      Espresso::Window.poll_events
      delta_time = (Time.utc - start_time).total_seconds
    end
  end
end
