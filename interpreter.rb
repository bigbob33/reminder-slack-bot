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
      # interpreting...
      publish(parsed_body.to_json, queue: 'slackbot.processed_messages')
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
end

puts ' [*] Waiting for messages. To exit press CTRL+C'
Interpreter.run
