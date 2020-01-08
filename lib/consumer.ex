defmodule Rabbit.Consumer.State do
  @moduledoc """
    Rabbit Consumer state.
  """

  defstruct [:connection,
             :channel,
             :queue,
             :hook,
             :consumer_pid,
             :consumer_tag,
             :mon_ref]
end

defmodule Rabbit.Consumer do
  @moduledoc """
  Documentation for Rabbit Consumer.
  """

  use GenServer
  use AMQP

  alias Rabbit.Consumer.State

  # ------------------
  # API Implementation
  # ------------------
  @spec start_link(any, any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(connection, queue) do
    GenServer.start_link(__MODULE__, [connection, queue])
  end

  @spec consume(any, any) :: any
  def consume(queue, count \\ 1) do
    Rabbit.Consumer.Manager.consume(queue, count)
  end

  @spec info(atom | pid | {atom, any} | {:via, atom, any}) :: any
  def info(pid) do
    GenServer.call(pid, :get_info)
  end

  @spec stop(any) :: :ok
  def stop(queue \\ :all) do
    Rabbit.Consumer.Manager.stop queue
  end

  @spec exit :: :ok
  def exit(), do: :init.stop()

  # -------------------
  # GenServer callbacks
  # -------------------
  @spec init([...]) :: {:ok, Rabbit.Consumer.State.t()}
  def init([connection, queue]) do
    hook = Application.get_env(:rabbitmq_consumer, :hook,
      Module.concat([Rabbit, Consumer, Dummy, Hook]))
    send(self(), :consume)
    {:ok, %State{connection: connection,
                 queue: queue,
                 consumer_pid: self(),
                 hook: validate_hook(hook)}}
  end

  def handle_call(:get_info, _from, state) do
    {:reply, {:ok, Map.to_list(state)}, state}
  end

  def handle_cast(:stop, state = %State{channel: channel,
                                        consumer_tag: consumer_tag}) do
    try do
      Basic.cancel(channel, consumer_tag)
      Channel.close(channel)
    catch
      _, _ -> :ok
    end
    send(self(), :shutdown)
    {:noreply, state}
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  def handle_info(:consume, state = %State{connection: conn,
                                           queue: queue}) do
    try do
      {:ok, channel} = AMQP.Channel.open(conn)
      mref = Process.monitor(channel.pid)
      {:ok, consumer_tag} = Basic.consume(channel, queue, self())
      {:noreply, %State{state | channel: channel,
                                consumer_tag: consumer_tag,
                                mon_ref: mref}}
    catch
      _, _ ->
        {:stop, :normal, state}
    end

  end

  def handle_info({:DOWN, mref, :process, channel_pid, _error},
      state = %State{mon_ref: mref, channel: %Channel{pid: channel_pid}}) do
    {:stop, :normal, state}
  end

  def handle_info({:basic_consume_ok, _}, state) do
    {:noreply, state}
  end
  def handle_info({:basic_cancel_ok, _}, state) do
    {:noreply, state}
  end
  def handle_info(message = {:basic_deliver, _payload, %{delivery_tag: tag}},
                  state   = %State{channel: channel,
                                   hook: hook}) do
    try do
      :ok = hook.forward(message)
      Basic.ack(channel, tag)
    catch
      _, _ -> Basic.nack(channel, tag)
    end
    {:noreply, state}
  end
  def terminate(_reason, %State{}) do
      :ok
  end

  defp validate_hook(hook) when is_binary(hook), do: validate_hook(String.to_atom(hook))
  defp validate_hook(hook) do
    case Code.ensure_loaded(hook) do
      {:module, _module} ->
        hook
      _ ->
        throw({:error, {:module_not_found, hook}})
    end
  end

end
