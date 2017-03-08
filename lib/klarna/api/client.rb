require 'xmlrpc/client'

module Klarna
  module Api
    # Klarna XML-RPC API Client
    class Client

      VERSION = 'ruby:api:1.1.3'
      KLARNA_API_VERSION = '4.1'
      VALID_ENVS = [:test, :production]

      attr_reader   :merchant_id, :environment
      attr_accessor :shared_secret, :keepalive, :country, :language, :currency

      def initialize(config = {})
        self.merchant_id = Klarna::Api.merchant_id
        self.shared_secret = Klarna::Api.shared_secret
        self.environment = Klarna::Api.environment || :test
        self.keepalive = false
        self.config = config
      end

      def merchant_id=(new_id)
        @merchant_id = new_id.to_i
      end

      def environment=(new_env)
        new_env = new_env.to_sym
        unless VALID_ENVS.include?(new_env)
          raise "Environment must be one of: #{VALID_ENVS.join(', ')}"
        end
        @environment = new_env
      end

      def config=(hash)
        hash.each do |key, value|
          setter = "#{key}="
          self.send(setter, value) if self.respond_to?(setter)
        end
      end

      # Activates a reservation matching the given reservation number.
      #
      # @see Klarna::Api::Activate
      #
      # @param [String] rno - Klarna order reservation number
      # @param [Hash] optional_info
      #
      # @return [Array] [risk_status, invoice_number]
      def activate(rno, optional_info = {})
        unless rno.present?
          raise 'Order reference must be present!'
        end

        defaults = {
          flags: Klarna::Api::Flags::RSRV_SEND_BY_EMAIL
        }

        params = Activate.params_list(self, rno, defaults.merge(optional_info))

        xmlrpc_client.call( 'activate', KLARNA_API_VERSION, VERSION, *params )
      end

      private

      # Initializes the XMLRPC::Client with klarna settings.
      #
      # @return [XMLRPC::Client] xmlrpc_client
      def xmlrpc_client
        return @xmlrpc_client if @xmlrpc_client

        @xmlrpc_client = XMLRPC::Client.new_from_hash(
          host: host,
          path: '/',
          port: 443,
          use_ssl: true
        )
        @xmlrpc_client.http_header_extra = headers
        @xmlrpc_client
      end

      # Returns the klarna host.
      #
      # @return [String] host
      def host
        if environment == :production
          'payment.klarna.com'
        else
          'payment.testdrive.klarna.com'
        end
      end

      # Returns the headers for the connection.
      #
      # @return [Hash] headers
      def headers
        @headers = {}
        @headers['Accept-Encoding'] = 'gzip,deflate'
        @headers['Accept-Charset']  = 'UTF-8,ISO-8859-1,US-ASCII'
        @headers['User-Agent']      = "XMLRPC::Client (Ruby #{RUBY_VERSION})"
        @headers['Content-Type']    = 'text/xml; charset=ISO-8859-1'
        @headers['Connection']      = 'close' unless keepalive
        @headers
      end

    end
  end
end