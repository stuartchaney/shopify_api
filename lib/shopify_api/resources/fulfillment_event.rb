module ShopifyAPI
  class FulfillmentEvent < Base
    self.prefix = "/admin/api/#{superclass.api_version}/orders/:order_id/fulfillments/:fulfillment_id/"
    self.collection_name = 'events'
    self.element_name = 'event'

    def order_id
      @prefix_options[:order_id]
    end

    def fulfillment_id
      @prefix_options[:fulfillment_id]
    end
  end
end
