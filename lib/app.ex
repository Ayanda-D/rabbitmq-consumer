defmodule Rabbit.Consumer.App do
  @moduledoc """
    Rabbit Consumer Application callback
  """

  use Application

  @spec start :: {:ok, pid}
  def start, do: start(:normal, [])

  @spec start(any, any) :: {:ok, pid}
  def start(_type, _args) do
    {:ok, _sup} = Rabbit.Consumer.Sup.start_link
  end

end
