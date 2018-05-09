defmodule Technic do
  @admin_ex_name  "admin_msg"
  @doctor_ex_name  "doctor_msg"
  @technic_ex_name  "technic_msg"
  @analize_time_sec  5

  def start(spec) do
    {:ok, connection} = AMQP.Connection.open
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, %{queue: my_queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    AMQP.Basic.consume(channel, my_queue_name)
    AMQP.Basic.qos(channel, prefetch_count: 1)


    # admin
    AMQP.Exchange.declare(channel, @admin_ex_name, :fanout)
    AMQP.Queue.bind(channel, my_queue_name, @admin_ex_name)

    # technic
    AMQP.Exchange.declare(channel, @technic_ex_name, :topic)
    for my_spceialisation <- spec do
      AMQP.Queue.declare(channel, my_spceialisation)
      AMQP.Basic.consume(channel, my_spceialisation)
      AMQP.Queue.bind(channel, my_spceialisation, @technic_ex_name, routing_key: my_spceialisation)
    end


    IO.puts("[Techinc #{inspect spec}] Ready")
    rec(spec, channel)
  end


  defp rec(spec, channel) do
    receive do
      {:basic_deliver, payload, %{exchange: @admin_ex_name} = meta} ->
        payload = String.split(payload, "\n")
        print(spec, payload)
        AMQP.Basic.ack(channel, meta.delivery_tag)

      {:basic_deliver, payload, meta} ->
        payload = String.split(payload, "\n")
        print(spec, payload)

        [routing_key, typ, patient_data] = payload
        IO.puts("Analize #{typ}")
        analized_data = analize(patient_data)
        IO.puts("Success")

        msg = Enum.join([:done, typ, analized_data], "\n")
        AMQP.Basic.publish(channel, @doctor_ex_name, routing_key, msg)
        AMQP.Basic.ack(channel, meta.delivery_tag)
    end
    rec(spec, channel)
  end

  defp print(spec, msg) do
    IO.puts("[Techinc #{inspect spec}] Received: #{inspect msg}")
  end

  defp analize(data)do
    :timer.sleep(1000 * @analize_time_sec)
    data
  end
end


specifications = [
  ["hip", "knee"],
  ["hip", "elbow"],
  ["knee", "elbow"],
]

my_spec =
  case System.argv do
    [] -> Enum.at(specifications, :rand.uniform(3) - 1)
    words -> words
  end

Technic.start(my_spec)
