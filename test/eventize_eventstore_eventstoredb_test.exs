defmodule EventizeEventstoreEventStoreDBTest do
  use Eventize.EventStore.EventStoreTestCase, event_store: Eventize.Eventstore.EventStoreDB

  defp before_start() do
    port = 2113
    name = UUID.uuid4()

    System.cmd("docker", [
      "run",
      "-d",
      "--rm",
      "--name",
      name,
      "-it",
      "-p",
      "#{port}:2113",
      "-e",
      "EVENTSTORE_INSECURE=True",
      "-e",
      "EVENTSTORE_ENABLE_ATOM_PUB_OVER_HTTP=True",
      "eventstore/eventstore:latest"
    ])

    on_exit(fn ->
      System.cmd("docker", ["stop", name])
    end)

    nil
  end

  defp get_start_options() do
    {:ok, event_store} =
      Spear.Connection.start_link(connection_string: "esdb://admin:changeit@127.0.0.1:2113")

    :ready = wait_for_event_store(event_store)

    [event_store: event_store]
  end

  defp wait_for_event_store(event_store, tries \\ 0) do
    case {tries, Spear.ping(event_store)} do
      {_, :pong} ->
        :ready

      {t, _} when t > 20 ->
        :error

      {_, _} ->
        Process.sleep(200)
        wait_for_event_store(event_store, tries + 1)
    end
  end
end
