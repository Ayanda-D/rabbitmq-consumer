defmodule Rabbit.Consumer.Dummy.Hook do
  @moduledoc """
    Documentation for Rabbit Consumer Dummy Hook callback.
  """
  require Logger

  use Rabbit.Consumer.Hook

  @spec forward(Rabbit.Consumer.Hook.delivery_message_t) :: :ok
  def forward(message = {:basic_deliver, _payload, %{delivery_tag: _tag}}) do
    # process or forward message ...
    IO.inspect message
    :ok
  end

end
