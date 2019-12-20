module ShopifyAPI
  class Product < Base
    include Events
    include Metafields

    early_july_pagination_release!

    # compute the price range
    def price_range
      prices = variants.collect(&:price).collect(&:to_f)
      format =  "%0.2f"
      if prices.min != prices.max
        "#{format % prices.min} - #{format % prices.max}"
      else
        format % prices.min
      end
    end

    def serializable_hash(options = {})
      super.except("total_inventory")
    end

    def total_inventory=(new_value)
      raise(ShopifyAPI::ValidationException, 'deprecated behaviour') unless Base.api_version < ApiVersion.find_version('2019-10')
      super
    end

    def collections
      CustomCollection.find(:all, :params => {:product_id => self.id})
    end

    def smart_collections
      SmartCollection.find(:all, :params => {:product_id => self.id})
    end

    def add_to_collection(collection)
      collection.add_product(self)
    end

    def remove_from_collection(collection)
      collection.remove_product(self)
    end
  end
end
