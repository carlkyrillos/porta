class AccountBillingAddressErrorRepresenter < ThreeScale::Representer
  wraps_resource :error

  property :object, extend: ->(options) { "#{options[:input].class}Representer".constantize }
  property :errors, getter: ->(*) { message }

  class JSON < AccountBillingAddressErrorRepresenter
    include Roar::JSON
  end

  class XML < AccountBillingAddressErrorRepresenter
    include Roar::XML
    wraps_resource :error
  end
end
