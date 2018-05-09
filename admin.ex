defmodule Admin do
  @admin_ex_name  "admin_msg"
  @doctor_ex_name  "doctor_msg"
  @technic_ex_name  "technic_msg"


  def start do
    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, %{queue: my_queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    AMQP.Basic.consume(channel, my_queue_name, nil, no_ack: true)


    # admin
    AMQP.Exchange.declare(channel, @admin_ex_name, :fanout)

    # doctor
    AMQP.Exchange.declare(channel, @doctor_ex_name, :topic)
    AMQP.Queue.bind(channel, my_queue_name, @doctor_ex_name, routing_key: "#")

    # technic
    AMQP.Exchange.declare(channel, @technic_ex_name, :topic)
    AMQP.Queue.bind(channel, my_queue_name, @technic_ex_name, routing_key: "#")


    spawn(Admin, :send_admin_msg, [channel])
    wait_for_logs()
  end

  def send_admin_msg(channel)do
    msg = IO.gets("Get msg:")
          |> String.replace("\n", "")
    AMQP.Basic.publish(channel, @admin_ex_name, "", msg)
    IO.puts("Sent #{msg}")
    send_admin_msg(channel)
  end

  def wait_for_logs do
    receive do
      {:basic_deliver, payload, _meta} ->
        payload = String.split(payload, "\n")
        IO.puts("\n[Admin] Received: #{inspect payload}")
    end
    wait_for_logs()
  end
end

Admin.start()