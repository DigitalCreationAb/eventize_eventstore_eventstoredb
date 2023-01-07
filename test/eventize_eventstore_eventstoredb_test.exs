defmodule EventizeEventstoreEventStoreDBTest do
  use Eventize.EventStore.EventStoreTestCase, event_store: Eventize.Eventstore.EventStoreDB

  defp get_start_options() do
    {:ok, event_store} =
      Spear.Connection.start_link(connection_string: "esdb://admin:changeit@127.0.0.1:2113")

    [event_store: event_store]
  end
end
