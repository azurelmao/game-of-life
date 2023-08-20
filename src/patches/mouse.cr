require "espresso"

module Espresso
  struct Mouse
    def button(button : MouseButton) : ButtonState
      action = expect_truthy { LibGLFW.get_mouse_button(@pointer, button.native) }
      ButtonState.new(action.to_u8)
    end
  end
end
