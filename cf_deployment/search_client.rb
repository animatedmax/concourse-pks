require 'elasticsearch'
require 'yaml'
require 'json'

module CfDeployment
  class SearchClient
    attr_reader :updating_index, :current_index, :search_service

    def initialize(indexer, getter, current_app, printer = Kernel)
      @indexer = indexer
      @getter = getter
      @current_app = current_app
      @printer = printer
      @first_index = false
      connect_to_elasticsearch
      find_index_to_update
    end

    def index_site
      if !use_search?
        printer.puts "ALERT: Search indexing not enabled"
        return nil
      end 

      printer.puts ''
      printer.puts "Indexing to #{updating_index}"
      indexer.parse_pages do |page|
        printer.print '.'
        with_retry(wait: 10) do
          elasticsearch.index index: updating_index, type: 'page', body: page
        end
      end
      printer.puts ''
    end

    def swap_indices
      if !use_search?
        printer.puts "ALERT: Search indexing not enabled"
        return nil
      end 

      actions = [{add: {index: updating_index, alias: 'searching'}}]
      unless @first_index
        actions << {remove: {index: current_index, alias: 'searching'}}
      end

      printer.puts "Putting #{updating_index} into the searching alias and removing #{current_index}"

      with_retry do
        elasticsearch.indices.update_aliases body: { actions: actions }
      end
      delete_index(current_index) unless @first_index
    end

    def delete_index(index_name)
      return unless use_search?

      printer.puts "Deleting #{index_name}"

      with_retry do
        elasticsearch.indices.delete index: index_name, timeout: '2m'
      end
    end

    def use_search?
      !elasticsearch.nil?
    end

    private

    attr_reader :indexer, :getter, :current_app, :printer, :elasticsearch

    def connect_to_elasticsearch
      full_env = getter.request("/v2/apps/#{current_app[:guid]}/env")
      services = full_env.fetch('system_env_json').fetch('VCAP_SERVICES')

      search_url = get_elasticco_elasticsearch(services)
      @search_service = 'elastic.co' if search_url

      search_url ||= get_searchly_elasticsearch(services)
      @search_service ||= 'searchly' if search_url

      return nil unless search_url

      @elasticsearch = Elasticsearch::Client.new(url: search_url)
    end

    def get_elasticco_elasticsearch(services_hash)
      return nil unless services_hash.has_key?('user-provided')

      elastic = services_hash['user-provided'].detect { |service| service['name'] == 'elastic.co' }

      return nil unless elastic

      elastic['credentials']['sslUri']
    end

    def get_searchly_elasticsearch(services_hash)
      return nil unless services_hash.has_key?('searchly')

      services_hash['searchly'][0]['credentials']['sslUri']
    end

    def find_index_to_update
      if !use_search?
        printer.puts "ALERT: Search indexing not enabled"
        return nil
      end 

      index_base = current_app[:name].split('-')[0..-2].join('-')

      active_indices = elasticsearch.indices.get_alias(name: 'searching').keys
      @current_index = active_indices.detect { |index_name| index_name =~ /\A#{index_base}-(emerald|sapphire)\z/ }

      unless @current_index
        @current_index = "#{index_base}-emerald"
        @first_index = true
      end

      @updating_index = current_index.sub(/(?<=-)(emerald|sapphire)\z/, {'emerald' => 'sapphire', 'sapphire' => 'emerald'})

      settings = YAML.load_file(File.expand_path('../index-settings.yml', __FILE__))

      with_retry do
        begin
          elasticsearch.indices.create index: updating_index, body: settings
        rescue Exception => e
          json_message = e.message.sub(/\A\[\d+\]\s*/, '')
          error_details = JSON.parse(json_message)
          error_type = error_details.fetch('error', {}).fetch('type', '')
          if error_type == 'index_already_exists_exception'
            printer.puts "Index #{updating_index} already exists, deleting...\n"
            delete_index(updating_index)
          end

          raise e
        end
      end
    end

    def with_retry(wait: 30)
      retries_left = 3

      begin
        yield
      rescue Exception => e
        printer.puts(e.message)
        retries_left -= 1
        if retries_left > 0
          printer.puts("\nretrying in #{wait} seconds\n")
          sleep(wait)
          retry
        else
          printer.puts("\ngiving up after 3 retries\n")
          raise
        end
      end
    end
  end
end
