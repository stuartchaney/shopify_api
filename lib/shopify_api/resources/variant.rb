module ShopifyAPI
  class Variant < Base
    include Metafields
    include DisablePrefixCheck

    conditional_prefix :product

    def serializable_hash(options = {})
      super.except("inventory_quantity", "old_inventory_quantity")
    end

    def inventory_quantity=(new_value)
      raise(ShopifyAPI::ValidationException, 'deprecated behaviour') unless Base.api_version < ApiVersion.find_version('2019-10')
      super
    end

    def old_inventory_quantity=(new_value)
      raise(ShopifyAPI::ValidationException, 'deprecated behaviour') unless Base.api_version < ApiVersion.find_version('2019-10')
      super
    end
  end
end
