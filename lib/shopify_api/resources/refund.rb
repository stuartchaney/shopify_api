module ShopifyAPI
  class Refund < Base
    init_prefix :order

    def self.calculate(*args)
      options = { :refund => args[0] }
      params = options.merge(args[1][:params]) if args[1] && args[1][:params]
      self.prefix = "/admin/api/#{superclass.api_version}/orders/#{params[:order_id]}/"
      resource = post(:calculate, {}, options.to_json)
      instantiate_record(format.decode(resource.body), {})
    end
  end
end
