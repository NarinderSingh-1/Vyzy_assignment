class ScraperController < ApplicationController
  def index
    url = params[:url]
    if url.present?
      browser = Watir::Browser.new :chrome
      scraper = ScraperService.new(url)
      @companies = ScraperService.get_details(browser, params)
      browser.close
      csv_file_path = Rails.root.join('public', 'scraped_data.csv')
      scraper.export_to_csv(@companies, csv_file_path)

      respond_to do |format|
        format.html
      end
    end
  end
end
