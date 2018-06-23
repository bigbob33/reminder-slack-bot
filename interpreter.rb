require 'bunny'
require 'json'

class Interpreter
  def initialize
    @bunny_con = Bunny.new
    @bunny_con.start

    @channel = @bunny_con.create_channel
    @input   = @channel.queue('slackbot.raw_messages')
    @logger  = Logger.new(STDOUT)
  end

  def run
    @input.subscribe(block: true) do |_delivery_info, _properties, body|
      @logger.info "Incoming message: #{body}"
      parsed_body = JSON.parse(body)

      reminders(parsed_body['users'], parsed_body['message']).each do |message|
        publish(message, queue: 'slackbot.processed_messages')
      end
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

  private

  def publish(message, queue:)
    @channel.default_exchange.publish(message, routing_key: queue)
    @logger.info "Outgoing message: #{message}"
  end

  def reminders(users, message)
    return [json_msg('#general', message)] if users.empty?
    users.map { |user| json_msg(user, message) }
  end

  def json_msg(channel, message)
    { channel: channel, message: message }.to_json
  end
end

puts ' [*] Waiting for messages. To exit press CTRL+C'
Interpreter.run
