# frozen_string_literal: true

module BlacklightMaps
  module Controller
    extend ActiveSupport::Concern

    included do
      blacklight_config.add_facet_field :coordinates,
                                        filter_class: BlacklightMaps::CoordinatesFilterField,
                                        filter_query_builder: BlacklightMaps::SpatialFilterQuery,
                                        item_presenter: BlacklightMaps::SpatialItemPresenter,
                                        show: false,
                                        include_in_request: false,
                                        label: 'Spatial Search'
    end

    def map
      @response = search_service.search_results
      params[:view] = 'maps'
      respond_to do |format|
        format.html
      end
    end

    ##
    # BlacklightMaps override: update to look for spatial query params
    # Check if any search parameters have been set
    # @return [Boolean]
    def has_search_parameters?
      params[:coordinates].present? || super
    end
  end
end
