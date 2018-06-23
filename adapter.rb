require 'slack-ruby-client'
require 'bunny'

Slack.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

client = Slack::Web::Client.new
client.auth_test

connection = Bunny.new
connection.start

channel = connection.create_channel
queue   = channel.queue('slackbot.raw_messages')

logger = Logger.new(STDOUT)

begin
  puts ' [*] Waiting for messages. To exit press CTRL+C'
  queue.subscribe(manual_ack: true, block: true) do |delivery_info, _properties, body|
    logger.info "Incoming message: #{body}"
    parsed_body = JSON.parse(body)
    client.chat_postMessage(channel: '#general', text: parsed_body['message'], as_user: true)
    channel.ack(delivery_info.delivery_tag)
  end
rescue Interrupt => _
  connection.close
  exit(0)
end
