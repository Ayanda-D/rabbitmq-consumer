use Mix.Config

config :rabbitmq_consumer, :hook,
  Rabbit.Consumer.Dummy.Hook

config :rabbitmq_consumer, :config,
  host: "localhost",
  port: 5672,
  virtual_host: "/",
  username: "guest",
  password: "guest"
