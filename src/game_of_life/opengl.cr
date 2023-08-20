require "stumpy_png"

module GameOfLife::OpenGL
  extend self

  def set_int(shader_program, location, int)
    LibGL.uniform_1i(LibGL.get_uniform_location(shader_program, location), int)
  end

  def set_float(shader_program, location, float)
    LibGL.uniform_1f(LibGL.get_uniform_location(shader_program, location), float)
  end

  def set_vec2(shader_program, location, vec2)
    LibGL.uniform_2fv(LibGL.get_uniform_location(shader_program, location), 1, vec2.to_unsafe)
  end

  def set_vec3(shader_program, location, vec3)
    LibGL.uniform_3fv(LibGL.get_uniform_location(shader_program, location), 1, vec3.to_unsafe)
  end

  def set_vec4(shader_program, location, vec4)
    LibGL.uniform_4fv(LibGL.get_uniform_location(shader_program, location), 1, vec4.to_unsafe)
  end

  def set_matrix(shader_program, location, matrix)
    LibGL.uniform_matrix4_fv(LibGL.get_uniform_location(shader_program, location), 1, LibGL::Boolean::False, matrix.to_unsafe)
  end

  def shader_program(vertex_shader : UInt32, fragment_shader : UInt32) : UInt32
    # Create shader program
    shader_program = LibGL.create_program
    LibGL.attach_shader(shader_program, vertex_shader)
    LibGL.attach_shader(shader_program, fragment_shader)
    LibGL.link_program(shader_program)

    # Check for compile errors
    LibGL.get_program_iv(shader_program, LibGL::ProgramPropertyARB::LinkStatus, out compiled)
    if compiled == 0
      Log.error("Shader program linking failed!")
      LibGL.get_program_iv(shader_program, LibGL::ProgramPropertyARB::InfoLogLength, out log_length)
      log = Pointer(UInt8).malloc(log_length)
      LibGL.get_program_info_log(shader_program, log_length, nil, log)
      puts String.new(log)
    else
      Log.info("Shader program linking succeeded!")
    end

    LibGL.delete_shader(vertex_shader)
    LibGL.delete_shader(fragment_shader)
    shader_program
  end

  def shader(source : UInt8*, type : LibGL::ShaderType) : UInt32
    # Create shader
    shader = LibGL.create_shader(type)
    LibGL.shader_source(shader, 1, pointerof(source), nil)
    LibGL.compile_shader(shader)

    # Check for compile errors
    LibGL.get_shader_iv(shader, LibGL::ShaderParameterName::CompileStatus, out compiled)
    if compiled == 0
      Log.error("#{type} compilation failed!")
      LibGL.get_shader_iv(shader, LibGL::ShaderParameterName::InfoLogLength, out log_length)
      log = Pointer(UInt8).malloc(log_length)
      LibGL.get_shader_info_log(shader, log_length, nil, log)
      puts String.new(log)
    else
      Log.info("#{type} compilation succeeded!")
    end

    shader
  end

  def texture(texture : StumpyPNG::Canvas)
    texture_data = texture.pixels.to_unsafe.unsafe_as(Pointer(UInt16))

    # Create texture
    LibGL.gen_textures(1, out opengl_texture)
    LibGL.bind_texture(LibGL::TextureTarget::Texture2D, opengl_texture)

    # Texture settings
    LibGL.tex_parameter_i(LibGL::TextureTarget::Texture2D, LibGL::TextureParameterName::TextureWrapS, LibGL::TextureWrapMode::MirroredRepeat)
    LibGL.tex_parameter_i(LibGL::TextureTarget::Texture2D, LibGL::TextureParameterName::TextureWrapT, LibGL::TextureWrapMode::MirroredRepeat)
    LibGL.tex_parameter_i(LibGL::TextureTarget::Texture2D, LibGL::TextureParameterName::TextureMagFilter, LibGL::TextureMagFilter::Nearest)
    LibGL.tex_parameter_i(LibGL::TextureTarget::Texture2D, LibGL::TextureParameterName::TextureMinFilter, LibGL::TextureMinFilter::Linear)

    # Insert texture data
    LibGL.tex_image_2d(LibGL::TextureTarget::Texture2D, 0, LibGL::InternalFormat::RGBA, texture.width, texture.height, 0, LibGL::PixelFormat::RGBA, LibGL::PixelType::UnsignedShort, texture_data)

    opengl_texture
  end
end
