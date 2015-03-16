require 'xmlrpc/client'
require 'digest'

module Klarna

  # Klarna XML-RPC API
  class Api

    VERSION = 'ruby:api:1.1.3'

    KLARNA_API_VERSION = '4.1'

    attr_accessor :keepalive, :merchant_id, :secret, :country, :language,
      :currency, :server, :pc_storage, :pc_uri, :environment, :use_ssl, :host,
      :path, :port

    def initialize(config = {})
      @path = '/'
      @port = 443
      @use_ssl = true
      @keepalive = false
      @environment = :production
      @pc_storage = 'json'
      @pc_uri = './pclasses.json'
      self.config = config
    end

    def config=(hash)
      hash.each do |key, value|
        setter = "#{key}="
        self.send(setter, value) if self.respond_to?(setter)
      end
    end

    # Digest
    #
    # Build digest. Any field in optional_info that is set is included in
    # the digest.
    #
    # Consist of all values from the variables which you send in the call
    # separated with a colon without the square brackets. Variables in
    # parentheses are optional.
    # If you are not sending a variable, remove that from the digest. Shared
    # secret must be the last variable.
    #
    # Example:
    #   base64encode(sha512("4:1:[client_vsn]:[eid]:[rno]:[flags](:[orderid1])
    #         (:[orderid2])(:[referece])(:[reference_code]):[shared_secret]"))
    #
    # @param [String] rno
    # @param [Hash] optional_info
    #
    def digest(rno, optional_info)

      optional_keys = [
        :bclass,
        :cust_no,
        :flags,
        :ocr,
        :orderid1,
        :orderid2,
        :reference,
        :reference_code
      ]

      digest_optional_info = optional_info.values_at(optional_keys).compact

      if optional_info[:artnos]
        optional_info[:artnos].each do |article|
          digest_optional_info.push article[:artno]
          digest_optional_info.push article[:qty]
        end
      end

      array = [
        KLARNA_API_VERSION.gsub('.', ':'),
        VERSION,
        merchant_id,
        rno,
        *digest_optional_info,
        secret
      ]

      ::Digest::SHA512.base64digest(array.join(':'))
    end

    # Activates the order in klarna.
    #
    # @see https://developers.klarna.com/en/api-references-v1/manage-orders#activate
    #
    # optional_info structure
    #
    # Variable        Type      Description
    # -------------------------------------------------------------------------
    # orderid1        string    Order ID #1
    #
    # orderid2        string    Order ID #2
    #
    # flags           integer   4: Send the invoice by mail
    #                           8: Send the invoice by e-mail
    #                           512: "Klarna Mobil" transaction
    #
    # reference       string    The reference person for the purchase if it is
    #                           a company purchase. You can also use reference
    #                           variable to write a message or other important
    #                           information to the consumer on the invoice.
    #
    # reference_code  string    The reference code for the sale. You can also
    #                           use reference_code variable to write a message
    #                           or other important information to the consumer
    #                           on the invoice.
    #
    # ocr             string    The payment reference number which the consumer
    #                           will use to pay Klarna. Please ask for more
    #                           information from your integration sales contact.
    #
    # pin             string    Consumer’s PIN code when using “Klarna Mobil”
    #                           service
    #
    # artnos          hash      Used if you want to activate a part of an order.
    #                           See Artnos structure below for more information.
    #
    # shipping_info   hash      Used to send information about shipment like
    #                           tracking numbers. See shipment_info structure
    #                           below for more information.
    #
    #
    # artnos structure
    #
    # Variable  Type      Description
    # -----------------------------------------------------------
    # artno     string    Article number on item to be activated
    # qty       integer   Number of items to activate
    #
    #
    # TODO: shipment_info structure
    #
    def activate(rno, params = {})
      optional_info = params.fetch(:optional_info, {})

      params_list = [
        merchant_id,
        digest(rno, optional_info),
        rno,
        optional_info
      ]

      xmlrpc_client.call('activate', KLARNA_API_VERSION, VERSION, *params_list)
    end

    def xmlrpc_client
      return @xmlrpc_client if @xmlrpc_client

      @xmlrpc_client = XMLRPC::Client.new_from_hash(
        host: host,
        path: path,
        port: port,
        use_ssl: use_ssl
      )
      @xmlrpc_client.http_header_extra = headers
      @xmlrpc_client
    end

    def host
      if @host
        @host
      elsif environment == :production
        'payment.klarna.com'
      else
        'payment.testdrive.klarna.com'
      end
    end

    private

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
