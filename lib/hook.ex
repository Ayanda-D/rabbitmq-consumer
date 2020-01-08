defmodule Rabbit.Consumer.Hook.Behaviour do
  @moduledoc """
    Rabbit Consumer Hook Behaviour
    specification module.

  """

  @type return_t           :: :ok | {:error,  any()}
  @type delivery_message_t :: {:basic_deliver, any(), map()}

  @callback forward(delivery_message :: delivery_message_t) :: return_t

end

defmodule Rabbit.Consumer.Hook do
  @moduledoc """
    RabbitMQ Consumer Hook Behaviour usage module.

  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Rabbit.Consumer.Hook.Behaviour
    end
  end

end
