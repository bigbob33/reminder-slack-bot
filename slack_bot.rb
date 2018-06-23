require 'slack-ruby-bot'
require 'bunny'
require 'json'

STDOUT.sync = true

class MyView < SlackRubyBot::MVC::View::Base; end
class MyModel < SlackRubyBot::MVC::Model::Base; end

class MyController < SlackRubyBot::MVC::Controller::Base
  def ping
    client.say(channel: data.channel, text: "Wait for it...")
    set_reminder('pong')
  end

  private

  def bunny_conn
    @bunny_conn ||= Bunny.new
  end

  def set_reminder(message)
    bunny_conn.start
    ch = bunny_conn.create_channel
    q  = ch.queue("slackbot.raw_messages", :auto_delete => true)
    x  = ch.default_exchange

    x.publish(json_msg(message), :routing_key => q.name)
  end

  def json_msg(msg)
    { message: msg }.to_json
  end
end

class SlackBot < SlackRubyBot::Bot
  view = MyView.new
  model = MyModel.new
  @controller = MyController.new(model, view)
  @controller.class.command_class.routes.each do |route|
    STDERR.puts route.inspect
  end
end

SlackBot.run
