require 'shopify_api/version'

module ShopifyAPI
  class Base < ActiveResource::Base
    class InvalidSessionError < StandardError; end
    extend Countable
    self.timeout = 90
    self.include_root_in_json = false
    self.headers['User-Agent'] = ["ShopifyAPI/#{'7.1.0'}",
                                  "ActiveResource/#{ActiveResource::VERSION::STRING}",
                                  "Ruby/#{RUBY_VERSION}"].join(' ')

    def encode(options = {})
      same = dup
      same.attributes = {self.class.element_name => same.attributes} if self.class.format.extension == 'json'

      same.send("to_#{self.class.format.extension}", options)
    end

    def as_json(options = nil)
      root = options[:root] if options.try(:key?, :root)
      if include_root_in_json
        root = self.class.model_name.element if root == true
        { root => serializable_hash(options) }
      else
        serializable_hash(options)
      end
    end

    class << self
      alias next all
      alias previous all

      threadsafe_attribute(:api_version)
      if ActiveResource::Base.respond_to?(:_headers) && ActiveResource::Base.respond_to?(:_headers_defined?)
        def headers
          if _headers_defined?
            _headers
          elsif superclass != Object && superclass.headers
            superclass.headers
          else
            _headers ||= {}
          end
        end
      else
        def headers
          if defined?(@headers)
            @headers
          elsif superclass != Object && superclass.headers
            superclass.headers
          else
            @headers ||= {}
          end
        end
      end

      def cursor_based?(api_ver = nil)
        true 
      end 
      
      def all(*args)
        options = args.slice!(0) || {}

        options = options.with_indifferent_access
        if options[:params].present?
          options[:params].delete :page

          options[:params].slice!(:page_info, :limit, :fields) if options.dig(:params, :page_info).present?

          options[:params].delete_if { |_k, v| v.nil? }
        end

        find :all, *([options] + args)
      end

      #gems/activeresource-5.1.1/lib/active_resource/base.rb
      # Core method for finding resources. Used similarly to Active Record's +find+ method.
      #
      # ==== Arguments
      # The first argument is considered to be the scope of the query. That is, how many
      # resources are returned from the request. It can be one of the following.
      #
      # * <tt>:one</tt> - Returns a single resource.
      # * <tt>:first</tt> - Returns the first resource found.
      # * <tt>:last</tt> - Returns the last resource found.
      # * <tt>:all</tt> - Returns every resource that matches the request.
      #
      # ==== Options
      #
      # * <tt>:from</tt> - Sets the path or custom method that resources will be fetched from.
      # * <tt>:params</tt> - Sets query and \prefix (nested URL) parameters.
      #
      # ==== Examples
      #   Person.find(1)
      #   # => GET /people/1.json
      #
      #   Person.find(:all)
      #   # => GET /people.json
      #
      #   Person.find(:all, :params => { :title => "CEO" })
      #   # => GET /people.json?title=CEO
      #
      #   Person.find(:first, :from => :managers)
      #   # => GET /people/managers.json
      #
      #   Person.find(:last, :from => :managers)
      #   # => GET /people/managers.json
      #
      #   Person.find(:all, :from => "/companies/1/people.json")
      #   # => GET /companies/1/people.json
      #
      #   Person.find(:one, :from => :leader)
      #   # => GET /people/leader.json
      #
      #   Person.find(:all, :from => :developers, :params => { :language => 'ruby' })
      #   # => GET /people/developers.json?language=ruby
      #
      #   Person.find(:one, :from => "/companies/1/manager.json")
      #   # => GET /companies/1/manager.json
      #
      #   StreetAddress.find(1, :params => { :person_id => 1 })
      #   # => GET /people/1/street_addresses/1.json
      #
      # == Failure or missing data
      # A failure to find the requested object raises a ResourceNotFound
      # exception if the find was called with an id.
      # With any other scope, find returns nil when no data is returned.
      #
      #   Person.find(1)
      #   # => raises ResourceNotFound
      #
      #   Person.find(:all)
      #   Person.find(:first)
      #   Person.find(:last)
      #   # => nil
      def find(*arguments)
        scope   = arguments.slice!(0)
        options = arguments.slice!(0) || {}
        #Remove 'page' param
        begin
          options[:params].delete(:page)
          options[:params].delete("page")
        rescue
        end

        case scope
        when :all
          find_every(options)
        when :first
          collection = find_every(options)
          collection && collection.first
        when :last
          collection = find_every(options)
          collection && collection.last
        when :one
          find_one(options)
        else
          find_single(scope, options)
        end
      end

      def activate_session(session)
        raise InvalidSessionError.new("Session cannot be nil") if session.nil?
        self.site = session.site
        self.api_version = session.api_version
        self.headers.merge!('X-Shopify-Access-Token' => session.token)
      end

      def clear_session
        self.site = nil
        self.api_version = nil
        self.password = nil
        self.user = nil
        self.headers.delete('X-Shopify-Access-Token')
      end

      def init_prefix(resource)
        init_prefix_explicit(resource.to_s.pluralize, "#{resource}_id")
      end

      def init_prefix_explicit(resource_type, resource_id)
        self.prefix = "/admin/api/2019-10/#{resource_type}/:#{resource_id}/"

        define_method resource_id.to_sym do
          @prefix_options[resource_id]
        end
      end
    end

    def persisted?
      !id.nil?
    end

    private
    def only_id
      encode(:only => :id, :include => [], :methods => [])
    end
  end
end
