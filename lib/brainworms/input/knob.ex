defmodule Brainworms.Input.Knob do
  use GenServer
  alias Circuits.GPIO

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    case {GPIO.open("GPIO17", :input), GPIO.open("GPIO18", :input)} do
      {{:ok, pin_a}, {:ok, pin_b}} ->
        # Enable interrupts on both edges
        GPIO.set_interrupts(pin_a, :both)
        GPIO.set_interrupts(pin_b, :both)

        # Set pull-up resistors
        GPIO.set_pull_mode(pin_a, :pullup)
        GPIO.set_pull_mode(pin_b, :pullup)

        {:ok,
         %{
           pin_a: pin_a,
           pin_b: pin_b,
           previous_a: GPIO.read(pin_a),
           previous_b: GPIO.read(pin_b),
           position: 0
         }}

      _ ->
        Logger.warning("Could not initialize GPIO pins for rotary encoder - interrupts disabled")

        {:ok,
         %{
           pin_a: nil,
           pin_b: nil,
           previous_a: 0,
           previous_b: 0,
           position: 0
         }}
    end
  end

  # Handler for GPIO17 (Pin A)
  def handle_info({:circuits_gpio, "GPIO17", _timestamp, value}, state) do
    new_position =
      determine_direction(
        value,
        GPIO.read(state.pin_b),
        state.previous_a,
        state.previous_b,
        state.position
      )

    {:noreply, %{state | previous_a: value, position: new_position}}
  end

  # Handler for GPIO18 (Pin B)
  def handle_info({:circuits_gpio, "GPIO18", _timestamp, value}, state) do
    new_position =
      determine_direction(
        GPIO.read(state.pin_a),
        value,
        state.previous_a,
        state.previous_b,
        state.position
      )

    {:noreply, %{state | previous_b: value, position: new_position}}
  end

  defp determine_direction(a, b, previous_a, previous_b, position) do
    case {previous_a, previous_b, a, b} do
      # Clockwise
      {1, 1, 0, 1} -> position + 1
      # Clockwise
      {0, 1, 0, 0} -> position + 1
      # Clockwise
      {0, 0, 1, 0} -> position + 1
      # Clockwise
      {1, 0, 1, 1} -> position + 1
      # Counter-clockwise
      {1, 1, 1, 0} -> position - 1
      # Counter-clockwise
      {1, 0, 0, 0} -> position - 1
      # Counter-clockwise
      {0, 0, 0, 1} -> position - 1
      # Counter-clockwise
      {0, 1, 1, 1} -> position - 1
      # No change or invalid state
      _ -> position
    end
  end

  # Get current position
  def get_position do
    GenServer.call(__MODULE__, :get_position)
  end

  def handle_call(:get_position, _from, state) do
    {:reply, state.position, state}
  end
end
