require 'net/http'
require 'uri'
require 'json'
require 'socket'
require 'thread'

module EphemeraNode
  class RackMiddleware
    def initialize(app, options = {})
      @app = app
      @api_key = options[:api_key] || ENV['EPHEMERANODE_API_KEY']
      @endpoint = URI.parse(options[:endpoint] || ENV['EPHEMERANODE_ENDPOINT'] || 'http://localhost:8080/ingest')
      @queue = Queue.new
      @service_name = options[:service_name] || Rails.application.class.module_parent_name.downcase rescue 'ruby-service'
      
      start_worker
    end

    def call(env)
      begin
        @app.call(env)
      rescue Exception => e
        capture_exception(e, env)
        raise e
      end
    end

    private

    def capture_exception(exception, env)
      payload = {
        timestamp: Time.now.utc.iso8601(3),
        service: @service_name,
        error_class: exception.class.name,
        message: exception.message,
        stack_trace: exception.backtrace.join("\n"),
        metadata: {
          request_method: env['REQUEST_METHOD'],
          path: env['PATH_INFO'],
          query_string: env['QUERY_STRING'],
          host: Socket.gethostname,
          language: 'ruby',
          runtime: "Ruby #{RUBY_VERSION}"
        }
      }

      @queue << payload
    end

    def start_worker
      Thread.new do
        loop do
          begin
            event = @queue.pop
            send_to_collector(event)
          rescue => e
            warn "[EphemeraNode] Failed to report error: #{e.message}"
            sleep 5
          end
        end
      end
    end

    def send_to_collector(payload)
      http = Net::HTTP.new(@endpoint.host, @endpoint.port)
      http.open_timeout = 2
      http.read_timeout = 2
      
      request = Net::HTTP::Post.new(@endpoint.path)
      request['Content-Type'] = 'application/json'
      request['X-Api-Key'] = @api_key
      request.body = payload.to_json

      response = http.request(request)
      unless response.code.to_i == 200 || response.code.to_i == 202
        warn "[EphemeraNode] Ingestion failed with status #{response.code}: #{response.body}"
      end
    end
  end
end

# Rails Railtie for automatic injection
if defined?(Rails::Railtie)
  class EphemeraNodeRailtie < Rails::Railtie
    initializer "ephemeranode.configure_rails_initialization" do |app|
      app.config.middleware.insert_before 0, EphemeraNode::RackMiddleware
    end
  end
end