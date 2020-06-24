module ShopifyAPI
  class Connection < ActiveResource::Connection
    attr_reader :response

    module ResponseCapture
      def handle_response(response)
        @response = super
      end
    end

    include ResponseCapture

    module RequestNotification
      def request(method, path, *arguments)
        super.tap do |response|
          notify_about_request(response, arguments, method, path)
        end
      rescue => e
        notify_about_request(e.response, arguments, method, path) if e.respond_to?(:response)
        raise
      end

      def notify_about_request(response, arguments, method = nil, path = nil)
        ActiveSupport::Notifications.instrument("request.active_resource_detailed") do |payload|
          payload[:response] = response
          payload[:data]     = arguments
          payload[:method]   =  method
          payload[:path]     =  path
        end
      end
    end

    include RequestNotification
  end
end
