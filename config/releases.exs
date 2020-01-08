import Config
config :rabbitmq_consumer, :hook,
  System.get_env("RABBITMQ_CONSUMER_HOOK", "Elixir.Rabbit.Consumer.Dummy")

config :rabbitmq_consumer, :config,
  host: System.get_env("RABBITMQ_CONSUMER_HOST", "localhost"),
  port: System.get_env("RABBITMQ_CONSUMER_PORT", "5672"),
  virtual_host: System.get_env("RABBITMQ_CONSUMER_VHOST", "/"),
  username: System.get_env("RABBITMQ_CONSUMER_USERNAME", "guest"),
  password: System.get_env("RABBITMQ_CONSUMER_PASSWORD", "guest"),
