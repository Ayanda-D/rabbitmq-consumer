defmodule Rabbit.Consumer.Manager.State do
  @moduledoc """
    Rabbit Consumer state.
  """

  defstruct [:host,
             :port,
             :virtual_host,
             :username,
             :password,
             :connection,
             :consumers,
             :mon_ref]
end

defmodule Rabbit.Consumer.Manager do
  @moduledoc """
  Documentation for Rabbit Consumer.
  """

  use GenServer
  use AMQP
  import  Supervisor.Spec

  require Logger

  alias Rabbit.Consumer.Manager.State

  @reconnect_interval 5_000

  # ------------------
  # API Implementation
  # ------------------
  @spec start_link(any, any, any, any, any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(host, port, virtual_host, username, password) do
    GenServer.start_link(__MODULE__, [host, port, virtual_host, username, password], name: __MODULE__)
  end

  @spec consume(any) :: :ok
  def consume(queue, count \\ 1) do
    GenServer.cast(__MODULE__, {:consume, queue, count})
  end

  @spec info() :: any
  def info() do
    GenServer.call(__MODULE__, :get_info)
  end

  @spec stop :: any
  def stop(queue \\ :all) do
    GenServer.cast(__MODULE__, {:stop, queue})
  end

  # -------------------
  # GenServer callbacks
  # -------------------
  @spec init([...]) :: {:ok, Rabbit.Consumer.Manager.State.t()}
  def init([host, port, virtual_host, username, password]) do
    send(self(), :connect)
    {:ok, %State{host: host,
                 port: ensure_port(port),
                 virtual_host: virtual_host,
                 username: username,
                 password: password,
                 consumers: []}}
  end

  def handle_call(:get_info, _from, state) do
    {:reply, {:ok, Map.to_list(state)}, state}
  end

  def handle_cast({:consume, queue, count},  state = %State{connection: conn,
                                                            consumers: consumer_pids}) do
    new_consumer_pids =
      for _n <- 1..count do
        {:ok, consumer_pid} = Supervisor.start_child(Rabbit.Consumer.Proc.Sup,
          worker(Rabbit.Consumer, [conn, queue], [id: id = consumer_id(count)]))
        {consumer_pid, {queue, id}}
      end

    {:noreply, %State{state | consumers: new_consumer_pids ++ consumer_pids}}
  end
  def handle_cast({:stop, :all}, state = %State{consumers: consumers}) do
    Enum.map(consumers,
             fn({consumer, {_queue, _id}}) ->
                GenServer.cast(consumer, :stop)
             end)
    {:noreply, %State{state | consumers: []}}
  end
  def handle_cast({:stop, queue}, state = %State{consumers: consumers}) do
    stopped_consumers =
      Enum.map(consumers,
              fn({consumer, {^queue, _id}} = consumer_key) ->
                  GenServer.cast(consumer, :stop)
                  consumer_key
                ({_consumer, {_queue, _id}}) ->
                  []
              end)
    stopped_consumers = List.flatten stopped_consumers
    {:noreply, %State{state | consumers: consumers -- stopped_consumers}}
  end

  def handle_info({:DOWN, mref, :process, conn_pid, _error},
    state = %State{mon_ref: mref,
    connection: %Connection{pid: conn_pid}}) do
    {:stop, :normal, state}
  end
  def handle_info({:EXIT, consumer_pid, _reason},
    state = %State{connection: conn, consumers: consumers}) do
    if Keyword.has_key?(consumers, consumer_pid) and Process.alive?(conn.pid) do
      consumers = Keyword.delete(consumers, consumer_pid)
      {:noreply, %State{state | consumers: consumers}}
    else
      {:stop, :normal, state}
    end
  end

  def handle_info(:connect, state = %State{host: host,
                                           port: port,
                                           virtual_host: virtual_host,
                                           username: username,
                                           password: password}) do
    case Connection.open([host: host,
                          port: port,
                          virtual_host: virtual_host,
                          username: username,
                          password: password]) do
      {:ok, conn} ->
        mon_ref = Process.monitor(conn.pid)
        {:noreply, %State{state | connection: conn, mon_ref: mon_ref}}

      {:error, _} ->
        Logger.error("Failed to connect #{host}. Reconnecting later...")
        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, nil}
    end
  end

  defp consumer_id(count) do
    timestamp = System.system_time(:nanosecond)
    Module.concat([Rabbit, Consumer, to_string(timestamp), to_string(:rand.uniform(count))])
  end

  defp ensure_port(port) when is_integer(port), do: port
  defp ensure_port(port) when is_binary(port), do: String.to_integer(port)

end
