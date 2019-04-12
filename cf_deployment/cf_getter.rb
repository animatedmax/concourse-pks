require 'json'
require 'uri'
require 'net/http'

module CfDeployment
  class CfGetter
    def initialize(account)
      @endpoint, @access_token = account.endpoint, account.access_token
    end

    def request(path, query=nil)
      uri = URI(endpoint)
      uri.path = path
      uri.query = query if query

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = access_token.strip
      request['Accept'] = 'application/json'
      request['Host'] = uri.hostname

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      response.value
      parse(response.body)
    end

    def get_all_pages(path, query=nil)
      page_response = request(path, query)
      resources = page_response.fetch('resources')

      until page_response.fetch('next_url').nil?
        next_page = page_response.fetch('next_url')
        page_response = request(*next_page.split('?'))
        resources.concat(page_response.fetch('resources'))
      end

      resources
    end

    private
    attr_reader :endpoint, :access_token

    def parse(perported_json)
      JSON.parse(perported_json)
    rescue Exception => e
      puts "unable to parse json:"
      p perported_json
      raise
    end
  end
end
