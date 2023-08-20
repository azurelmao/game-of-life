require "espresso"

module Espresso
  struct Espresso::MouseButtonEvent < Espresso::MouseEvent
    protected def initialize(pointer, button, action, mods)
      super(pointer)
      @button = MouseButton.new(button.to_u8)
      @state = ButtonState.new(action.to_u8)
      @modifiers = ModifierKey.new(mods.to_u8)
    end
  end
end
