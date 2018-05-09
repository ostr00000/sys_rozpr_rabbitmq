defmodule Doctor do
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
    AMQP.Queue.bind(channel, my_queue_name, @admin_ex_name)

    # doctor
    AMQP.Exchange.declare(channel, @doctor_ex_name, :topic)
    AMQP.Queue.bind(channel, my_queue_name, @doctor_ex_name, routing_key: my_queue_name)

    # technic
    AMQP.Exchange.declare(channel, @technic_ex_name, :topic)
    for typ <- ["knee", "hip", "elbow"] do
      AMQP.Queue.declare(channel, typ)
      AMQP.Queue.bind(channel, typ, @technic_ex_name, routing_key: typ)
    end


    spawn(Doctor, :next_patient, [channel, my_queue_name])
    wait_for_messages()
  end

  def next_patient(channel, my_routing_key)do
    patient_data = IO.gets("Next patient:")
                   |> String.replace("\n", "")
    typ = IO.gets("Get typ [h, k, e]:")
          |> String.replace("\n", "")
          |> String.downcase()
          |> case do
               "k" -> "knee"
               "h" -> "hip"
               "e" -> "elbow"
               ___ -> ""
             end
    cond do
      typ != "" ->
        msg = Enum.join([my_routing_key, typ, patient_data], "\n")
        AMQP.Basic.publish(channel, @technic_ex_name, typ, msg)
        IO.puts("Sent #{inspect msg} with topic: #{typ}")
      true -> IO.puts("Wrong typ")
    end

    next_patient(channel, my_routing_key)
  end

  def wait_for_messages do
    receive do
      {:basic_deliver, payload, _meta} ->
        payload = String.split(payload, "\n")
        IO.puts("\n[Doctor] Received: #{inspect payload}")
    end
    wait_for_messages()
  end
end

Doctor.start()
