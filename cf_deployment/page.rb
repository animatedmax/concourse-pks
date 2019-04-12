require 'nokogiri'

module CfDeployment
  class Page

    def initialize(relative_path, html)
      extract(html)

      @url = "/#{relative_path}"
    end

    def to_h
      {
        url: @url,
        title: @title,
        headings: @headings,
        text: @text,
        product_name: @product_name,
        product_version: @product_version,
        summary: @summary
      }
    end

    private

    def extract(html)
      doc = Nokogiri::HTML(html)

      header = doc.css('header')
      local_header = header.css('.embedded-searchbar')

      main = doc.css('main')

      @product_name = (local_header.css('input[name=product_name]').first || {})['value']
      @product_version = (local_header.css('input[name=product_version]').first || {})['value']
      remove_unwanted_elements(main)

      title = main.css('.title-container')
      @title = title.text.strip
      title.remove

      @headings = main.css('h2, h3').map(&:text).join(" ")
      @text = main.text.strip.gsub(/\s+/, ' ')
      @summary = @text[/(?:\S+(?:\s+)){,20}/].strip
    end

    def remove_unwanted_elements(main)
      ['.local-header', '.embedded-searchbar', '#js-quick-links', '#repo-link'].each do |selector|
        main.css(selector).remove
      end
    end
  end
end
