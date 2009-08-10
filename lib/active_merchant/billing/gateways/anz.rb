require 'cgi'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AnzGateway < Gateway
      
      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]
      self.money_format = :cents
      self.homepage_url = 'http://www.anz.com.au'
      self.display_name = 'ANZ eGate'
      GATEWAY_URL = "https://migs.mastercard.com.au/vpcdps"
      VIRTUAL_PAYMENT_CLIENT_API_VERION = 1
      
      def initialize(options={})
        requires!(options, :merchant_id, :access_code)
        if options[:mode] && (options[:mode].to_sym == :production || options[:mode].to_sym == :test)
          self.mode = options[:mode]
        end
        @options = options
        super
      end
      
      ########################################################
      # allowed operations for mastercard migs virtual gateway
      ########################################################
      
      #actual payment
      def purchase(money, creditcard, options = {})
        requires!(options, :invoice, :order_id)
        params = {}
        add_credit_card(params, creditcard)
        add_merchant_transaction_id(params, options[:order_id])
        add_invoice_number(params, options[:invoice])
        add_amount(params, money)
        process_action('pay', params)
      end
 
      ###############################################################
      ## Next two operations require a AMA username and AMA password
      
      #refunds to the customer's card. autorization id is required
      def credit(money, authorization_number, options = {})
        requires!(options, :username, :password, :order_id)
        params = {}
        add_merchant_transaction_id(params, options[:order_id])
        add_authorization_number(params, authorization_number)
        add_username_password(params, options[:username], options[:password])
        add_amount(params, money)
        process_action('refund', params)
      end
      
      #query a past payment, unique merchant transaction ref. is required
      def query(merchant_transaction_id)
        params = {}
        add_merchant_transaction_id(params, merchant_transaction_id)
        process_action('QueryDR', params)
      end

      private
      #########################################################
      #methods to beautify and prepare the params before handing over to bank
      #########################################################
      
      def process_action(action, params)
        payment_params = post_data(action, params)
        response = ssl_post GATEWAY_URL, payment_params
        build_response(response)
      end

      #ADDS 
      #
      #
      def post_data(action, params)
        return params.merge(:vpc_Version      => VIRTUAL_PAYMENT_CLIENT_API_VERION,
                            :vpc_AccessCode   => @options[:access_code],
                            :vpc_Merchant     => @options[:merchant_id],
                            :vpc_Command      => action).to_query
      end
      
      def add_invoice_number(params, invoice_number)
        return params.merge!(:vpc_TicketNo  => invoice_number,
                            :vpc_OrderInfo => invoice_number)
      end
      
      def add_credit_card(params, creditcard)
        return params.merge!(:vpc_CardNum => creditcard.number,
                             :vpc_CardSecurityCode => creditcard.verification_value,
                             :vpc_CardExp => "#{creditcard.year.to_s.last(2)}#{sprintf("%.2i", creditcard.month)}")
      end

      def add_amount(params, money)
        params[:vpc_Amount] = amount(money)
      end

      #ADDS THE AUTHORIZATION NUMBER OF A PREVIOUS TRANSACTION
      #IN THE REQUEST PARAMS. THIS IS MOSTLY USED IN A REFUND 
      #OR A QUERY FOR A PREVIOUSLY PERFORMED TRANSACTION
      def add_authorization_number(params, authorization)
        return params.merge!(:vpc_TransactionNo => authorization)
      end
      
      #ADDS A UNIQUE ID(can be alpanumeric) TO THE PARAMS LIST.
      #EVERY TRANSACTION SENT TO BANKING GATEWAY SHOULD HAVE A 
      #UNIQUE IDENTIFICATION NUMBER. THIS HELPS IN TRACING THE
      #TRANSACTION IN CASE OF QUERIES AND AUDITS. THIS IS A REQUIRED
      #FIELD IN EVERY REQUEST SENT TO GATEWAY.
      def add_merchant_transaction_id(params, transaction_id)
        return params.merge!(:vpc_MerchTxnRef => transaction_id)
      end
      
      #USED FOR REFUNDS AND QUERYING THE GATEWAY. NEED THE 
      #MA USERNAME AND PASSWORD REQUIRED. THESE ARE SUPPLIED
      #BY THE BANKING AUTHORITY.
      def add_username_password(params, username, password)
        return params.merge!(:vpc_User     => username,
                                :vpc_Password => password)
      end
      
      def build_response(response_str)
        response = parse(response_str)
        authorization = response['vpc_TransactionNo']
        success = (response['vpc_TxnResponseCode'] == '0')
        message = CGI.unescape(response['vpc_Message'])
        Response.new(success, message, response, :authorization => authorization, :test => test?)
      end
      
      def parse(html_encoded_url)
        params = CGI::parse(html_encoded_url)
        hash = {}
        params.each do|key, value| 
          hash[key] = value[0]
        end
        hash
      end
    end
  end
end