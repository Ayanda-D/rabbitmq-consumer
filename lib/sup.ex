defmodule Rabbit.Consumer.Sup do
  @moduledoc """
    Rabbit Consumer Main Supervisor
  """

  use Supervisor

  # ----
  # API
  # ----
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def stop() do
    Supervisor.stop(__MODULE__)
  end

  # ---------
  # Callbacks
  # ---------
  def init(_args) do
    config = Application.get_env(:rabbitmq_consumer, :config)
    children = [
      worker(Rabbit.Consumer.Manager, [
        config[:host],
        config[:port],
        config[:virtual_host],
        config[:username],
        config[:password]
      ]),
      supervisor(Rabbit.Consumer.Proc.Sup, [])]
    supervise(children, strategy: :one_for_one)
  end
end
