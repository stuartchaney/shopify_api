# frozen_string_literal: true
require 'graphql/client'
require 'shopify_api/graphql/http_client'

module ShopifyAPI
  module GraphQL
    DEFAULT_SCHEMA_LOCATION_PATH = Pathname('shopify_graphql_schemas')
    VERSION = '2020-04'

    InvalidSchema = Class.new(StandardError)
    InvalidClient = Class.new(StandardError)

    class << self
      delegate :parse, :query, to: :client

      def client(api_version = VERSION)
        initialize_client_cache
        cached_client = @_client_cache[api_version]

        if cached_client
          cached_client
        else
          schema_file = schema_location.join("#{api_version}.json")

          if !schema_file.exist?
            raise InvalidClient, <<~MSG
              Client for API version #{api_version} does not exist because no schema file exists at `#{schema_file}`.
              To dump the schema file, use the `rake shopify_api:graphql:dump` task.
            MSG
          else
            puts '[WARNING] Client was not pre-initialized. Ensure `ShopifyAPI::GraphQL.initialize_clients` is called during app initialization.'
            initialize_clients
            @_client_cache[api_version]
          end
        end
      end

      def clear_clients
        @_client_cache = {}
      end

      def initialize_clients(raise_on_invalid_schema: true)
        initialize_client_cache

        Dir.glob(schema_location.join("*.json")).each do |schema_file|
          schema_file = Pathname(schema_file)
          matches = schema_file.basename.to_s.match(/^#{VERSION}\.json$/)

          if matches
            api_version = VERSION #ShopifyAPI::ApiVersion.new(handle: matches[1])
          else
            if raise_on_invalid_schema
              raise InvalidSchema, "Invalid schema file name `#{schema_file}`. Does not match format of: `<version>.json`."
            else
              next
            end
          end

          schema = ::GraphQL::Client.load_schema(schema_file.to_s)
          client = ::GraphQL::Client.new(schema: schema, execute: HTTPClient.new(api_version)).tap do |c|
            c.allow_dynamic_queries = true
          end

          @_client_cache[api_version] = client
        end
      end

      def schema_location
        @schema_location || DEFAULT_SCHEMA_LOCATION_PATH
      end

      def schema_location=(path)
        @schema_location = Pathname(path)
      end

      def load_schema(shop_domain, access_token)
        shopify_session = ShopifyAPI::Session.new(shop_domain, access_token)
        ShopifyAPI::Base.activate_session(shopify_session)

        klient = ShopifyAPI::GraphQL::HTTPClient.new(VERSION)
        document = ::GraphQL.parse('{ __schema { queryType { name } } }')
        response = klient.execute(document: document).to_h

        unless response['data'].present?
          puts "Error: failed to query the API."
          puts "Response: #{response}"
          puts 'Ensure your SHOP_DOMAIN or SHOP_URL are valid and you have valid authentication credentials.'
          puts usage
          exit(1)
        end

        schema_location = ShopifyAPI::GraphQL.schema_location
        FileUtils.mkdir_p(schema_location) unless Dir.exist?(schema_location)

        schema_file = schema_location.join("#{VERSION}.json")
        ::GraphQL::Client.dump_schema(klient, schema_file.to_s)

        puts "Wrote file #{schema_file}"
      end

      private

      def initialize_client_cache
        @_client_cache ||= {}
      end
    end
  end
end
