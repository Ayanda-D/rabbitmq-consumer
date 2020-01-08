defmodule Rabbit.Consumer.Proc.Sup do
  @moduledoc """
    Rabbit Consumer Process Supervisor
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
    children = []
    supervise(children, max_restarts: 0, strategy: :one_for_one)
  end
end
