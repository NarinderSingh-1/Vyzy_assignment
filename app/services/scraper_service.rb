# app/services/scraper_service.rb

class ScraperService
  def initialize(url)
    @url = url
  end

  def export_to_csv(data, file_name)
    CSV.open(file_name, 'w') do |csv|
      # Write the header row
      csv << ['Name', 'Location', 'Description', 'YC Batch', 'Tags', 'Website', 'Founder Names', 'Founder LinkedIn Urls']

      # Write each company’s data
      data[:companies]&.each do |company|
        csv << [
          company[:name],
          company[:location],
          company[:description],
          company[:YC_batch],
          company[:all_tags]&.join(', '),  # Join tags into a single string
          company[:owner_details][:website],
          company[:owner_details][:founder_names]&.join(', '),
          company[:owner_details][:founder_linkedIn_urls]&.join(', '),
        ]
      end
    end
  end  
  
  def self.get_details(browser, params = {})
    csv_file_path = Rails.root.join('public', 'scraped_data.csv')
    @companies = []
    main_window = browser.window  # Store the main window
    url = params[:url]
    filters = params[:filters]
    company_count = params[:company_count]
    input_filters = params[:input_filters]
    status = "Completed"
    begin
      browser.goto url
      Watir.default_timeout = 60
      divs = browser.divs(class: '_facet_86jzd_85')
      browser.link(class: '_showMoreLess_86jzd_240').click
      browser.links(class: '_showMoreLess_86jzd_240')&.each do |link|
        if !link.text.include? 'fewer'
          link.click
        end
      end

      if filters
        divs&.each do |div|
          label_text = div.span(class: '_label_86jzd_224').text

          matching_filter = filters.find { |f| label_text.include?(f) }
    
          if matching_filter
            checkbox = div.checkbox
            checkbox.set # Check the checkbox
          end  
        end
      end

      if input_filters.values.any?(&:present?)
        divs&.each do |div|
          doc = Nokogiri::HTML(div.html)

          group_text = doc.css('h4').text.strip
          matching_group = input_filters[input_filters.keys.find { |f| group_text.include?(f) }]
    
          if matching_group.present?
            if group_text == "Company Size"
              min, max = matching_group.split('-')
              slider = div.div(class: 'noUi-target').to_subtype    
              # Set the lower handle to 0
              browser.execute_script("arguments[0].noUiSlider.setHandle(0, #{min});", slider)
              # Set the upper handle to 5
              browser.execute_script("arguments[0].noUiSlider.setHandle(1, #{max});", slider)
              break
            end
            if group_text == "Tags"
              div.input(type: 'text').set matching_group
              sleep 2
            end

            labels = div.labels
            labels&.each do |label|
              span_text = label.span(class: '_label_86jzd_224').text
              if span_text.include? matching_group
                checkbox = label.checkbox
                checkbox.set # Check the checkbox
                break
              end
            end
          end  
        end
      end

      # Scroll and scrape loop
      CSV.open(csv_file_path, 'w') do |csv|
        # Write the header row
        csv << ['Name', 'Location', 'Description', 'YC Batch', 'Tags', 'Website', 'Founder Names', 'Founder LinkedIn Urls']

        while @companies.size < company_count.to_i
          # Use Nokogiri to parse the page source
          browser.execute_script('window.scrollBy(0, document.body.scrollHeight)')
          doc = Nokogiri::HTML(browser.html)
 
          break if doc.css('a._company_86jzd_338').size < 1
          sleep 5
          # Iterate over each company section
          doc.css('a._company_86jzd_338')&.each do |company|
            name = company.css('span._coName_86jzd_453').text.strip
            location = company.css('span._coLocation_86jzd_469').text.strip
            description = company.css('span._coDescription_86jzd_478').text.strip
            # Initialize an empty array to store tags
            tags = []
            company.css('a._tagLink_86jzd_1023').each do |tag|
              tags << tag.text.strip
            end

            # Open the company link in a new tab
            company_url = company['href']
            browser.execute_script("window.open('#{company_url}', '_blank');")

            browser.switch_window
            sleep 2  # Adjust the sleep time if necessary
            # Get author details from the company page
            owner_details = {}
            begin
              author_page_doc = Nokogiri::HTML(browser.html)
              # Add the actual selectors for author details here
              website = author_page_doc.css('a.mb-2.whitespace-nowrap.md\\:mb-0')[0]['href']
              founder_names = []
              founder_linkedIn_urls = []
              author_page_doc.css('div.leading-snug')&.each do |founder|
                founder_names << founder.css('div.font-bold').text.strip
                founder_linkedIn_urls << founder.css('a.bg-image-linkedin')[0]['href']
              end

              owner_details = {
                website: website,
                founder_names: founder_names,
                founder_linkedIn_urls: founder_linkedIn_urls
              }
            rescue
              owner_details = {
                website: ['N/A'],
                founder_names: ['N/A'],
                founder_linkedIn_urls: ['N/A']
              }
            end
            browser.switch_window
            browser.window(url: /#{Regexp.escape(company_url)}/).close
            sleep 2  # Adjust the sleep time if necessary

            # Store the details in a hash
            company_details = {
              name: name,
              location: location,
              description: description,
              YC_batch: tags[0],
              all_tags: tags,
              owner_details: owner_details,
            }
            # Write each company’s data

            csv << [
              company_details[:name],
              company_details[:location],
              company_details[:description],
              company_details[:YC_batch],
              company_details[:all_tags]&.join(', '),  # Join tags into a single string
              company_details[:owner_details][:website],
              company_details[:owner_details][:founder_names]&.join(', '),
              company_details[:owner_details][:founder_linkedIn_urls]&.join(', '),
            ]

            @companies << company_details unless @companies.any? { |c| c[:name] == name }
            puts "==== Fetch #{@companies.size} Companies Data ====="
            break if @companies.size >= company_count.to_i
          end
          break if @companies.size >= company_count.to_i
          sleep 2
        end
      end

      puts "============================================="
      puts "============= Companies Details ============="
      puts "============================================="

      @companies&.each do |company|
        puts "Name: #{company[:name]}"
        puts "Location: #{company[:location]}"
        puts "Description: #{company[:description]}"
        puts "YC-Batch: #{company[:YC_batch]}"
        puts "Tags: #{company[:all_tags]&.join(', ')}"
        puts "-------------------------"
      end
      
      # Close the browser
      browser.close
      
    return {success: true, url: url, companies: @companies, status: status}
    rescue Exception => e
      puts "Error - #{e.message}"
      return {success: false, message: e.message}
    end
  end
end
