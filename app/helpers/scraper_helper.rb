# app/helpers/scraper_helper.rb

module ScraperHelper
  def form_filters
    filters = ['Batch', 'Industry', 'Region', 'Tag', 'Company Size']

    bool_filters = ['Is Hiring', 'Nonprofit', 'Black-founded',
      'Hispanic & Latino-founded', 'Women-founded'
    ]

    content_tag(:div, class: 'col-6') do
      filter_inputs = filters.map do |filter|
        content_tag(:div, class: 'form-group mb-3') do
          label_tag("input_filters[#{filter}]", filter, class: 'form-label col-4') +
          text_field_tag("input_filters[#{filter}]", params.dig(:input_filters, filter), id: "input_filters_#{filter.parameterize.underscore}", class: 'col-8')
        end
      end

      bool_filter_checks = bool_filters.map do |filter|
        content_tag(:div, class: 'form-group gap-4') do
          check_box_tag('filters[]', filter, false, id: "filters_#{filter.parameterize.underscore}", class: "me-3") +
          label_tag("filters_#{filter.parameterize.underscore}", filter)
        end
      end

      filter_inputs.concat(bool_filter_checks).join.html_safe
    end
  end
end
