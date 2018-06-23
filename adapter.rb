require 'slack-ruby-client'
require 'bunny'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

class Adapter
  def initialize
    @bunny_con = Bunny.new
    @bunny_con.start

    @slack_client = Slack::Web::Client.new
    @slack_client.auth_test

    @channel = @bunny_con.create_channel
    @input   = @channel.queue('slackbot.processed_messages')
    @logger  = Logger.new(STDOUT)
  end

  def run
    @input.subscribe(block: true) do |_delivery_info, _properties, body|
      @logger.info "Incoming message: #{body}"
      parsed_body = JSON.parse(body)
      @slack_client.chat_postMessage(channel: parsed_body['channel'], text: parsed_body['message'], as_user: true)
    end
  rescue Interrupt => _
    @bunny_con.close
    exit(0)
  end

  class << self
    def run
      new.run
    end
  end
end

puts ' [*] Waiting for messages. To exit press CTRL+C'
Adapter.run
