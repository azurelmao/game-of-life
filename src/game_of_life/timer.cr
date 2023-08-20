struct GameOfLife::Timer
  @previous_time = Time.utc.to_unix_ms
  getter elapsed_ticks = 0i64
  property tick_rate : Int32 # time between each tick in miliseconds

  def initialize(@tick_rate)
  end

  def update
    current_time = Time.utc.to_unix_ms
    elapsed_time = current_time - @previous_time
    if elapsed_time >= @tick_rate.to_f
      @previous_time = current_time
    end
    @elapsed_ticks = elapsed_time // @tick_rate.to_f
  end
end
