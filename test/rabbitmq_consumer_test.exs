defmodule RabbitmqConsumerTest do
  use ExUnit.Case

  setup_all do
    Application.ensure_started :rabbitmq_consumer
  end

  test "verify config loading" do
    {:ok, info} = Rabbit.Consumer.Manager.info
    assert info[:host] == "localhost"
    assert info[:port] == 5672
    assert info[:virtual_host] == "/"
    assert info[:username] == "guest"
    assert info[:password] == "guest"
  end

  test "verify successful consume execution" do
    # declare queue
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)
    AMQP.Queue.declare(chan, "TEST.QUEUE.1")
    AMQP.Queue.declare(chan, "TEST.QUEUE.2")

    # start N consumers
    Rabbit.Consumer.consume "TEST.QUEUE.1", 10
    Rabbit.Consumer.consume "TEST.QUEUE.2", 10

    :timer.sleep(100) # wait for consumers to be active

    # verify N consumers
    {:ok, info} = Rabbit.Consumer.Manager.info
    assert length(info[:consumers]) == 20
    assert length(Supervisor.which_children(Rabbit.Consumer.Proc.Sup)) == 20

    # stop consumers
    Rabbit.Consumer.Manager.stop "TEST.QUEUE.1"
    :timer.sleep(100) # wait for consumers to shutdown
    {:ok, info} = Rabbit.Consumer.Manager.info

    # verify '10' remaining consumers
    assert length(info[:consumers]) == 10
    assert length(Supervisor.which_children(Rabbit.Consumer.Proc.Sup)) == 10

    # stop consumers
    Rabbit.Consumer.Manager.stop "TEST.QUEUE.2"
    :timer.sleep(100) # wait for consumers to shutdown
    {:ok, info} = Rabbit.Consumer.Manager.info

    # verify '0' consumers
    assert length(info[:consumers]) == 0
    assert length(Supervisor.which_children(Rabbit.Consumer.Proc.Sup)) == 0

  end

  test "verify successful multiple consumer termination" do
    # declare queue
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)
    AMQP.Queue.declare(chan, "TEST.QUEUE.1")
    AMQP.Queue.declare(chan, "TEST.QUEUE.2")

    # start N consumers
    Rabbit.Consumer.consume "TEST.QUEUE.1", 10
    Rabbit.Consumer.consume "TEST.QUEUE.2", 10

    :timer.sleep(100) # wait for consumers to be active

    # verify N consumers
    {:ok, info} = Rabbit.Consumer.Manager.info
    assert length(info[:consumers]) == 20
    assert length(Supervisor.which_children(Rabbit.Consumer.Proc.Sup)) == 20

    # stop consumers
    Rabbit.Consumer.Manager.stop :all

    # verify '0' consumers
    assert length(info[:consumers]) == 0
    assert length(Supervisor.which_children(Rabbit.Consumer.Proc.Sup)) == 0
  end
end
