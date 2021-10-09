# How to recover from a failing amqp connection

When running an elixir service using an amqp/rabbitmq
message-bus you need to plan for the connection and/or
the channel to die unexepectedly.

Recovering from this is not as straight forward as
it sounds, because you first need to detect that the
connection/channel died and then you need to
recreate/reestablish it on the fly.

This repo shows one way to make this work.

* clone the repo
* run `docker run --interactive --tty --rm --name
 rabbitmq --publish 5672:5672 --publish 15672:15672 rabbitmq:3.9-management`
 to start a rabbitmq server
* run `mix deps.get && mix phx.server` to start the
elixir/phoenix server
* start a second terminal
* run `curl --silent --request GET http://localhost:4000/api/start`
to start publishing messages on the bus
* run `curl --silent --request GET http://localhost:4000/api/kill`
to kill the connection (and simulate a connection failure)
* wait for the connection to get recreated/reestablished
* run `curl --silent --request GET http://localhost:4000/api/stop`
to stop publishing messages
