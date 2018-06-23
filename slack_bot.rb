require 'slack-ruby-bot'
require 'bunny'
require 'json'

STDOUT.sync = true

class MyView < SlackRubyBot::MVC::View::Base; end
class MyModel < SlackRubyBot::MVC::Model::Base; end

class MyController < SlackRubyBot::MVC::Controller::Base
  USERS_REGEXP = /remind (.*) that/
  ACTIVITY_REGEXP = /that (.*)/
  USER_ID = /<@(.*)>/

  def remind
    message = data["text"]
    set_reminder(
      users(message),
      activity(message)
    )
    client.say(channel: data.channel, text: "Reminder sent")
  end

  private

  def users(message)
    raw_users = message.match(USERS_REGEXP)
    return [] if raw_users.nil?
    raw_users = raw_users.captures[0]
    raw_users = raw_users.split(/,\s*/)
    raw_users.map { |user| user.match(USER_ID).captures[0] }
  end

  def activity(message)
    message.match(ACTIVITY_REGEXP).captures[0]
  end

  def bunny_conn
    @bunny_conn ||= Bunny.new
  end

  def set_reminder(user, activity)
    bunny_conn.start
    ch = bunny_conn.create_channel
    q  = ch.queue("slackbot.raw_messages")
    x  = ch.default_exchange

    x.publish(json_msg(user, activity), :routing_key => q.name)
  end

  def json_msg(user, activity)
    { message: activity, user: user }.to_json
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
