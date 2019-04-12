require 'yaml'

require_relative 'cf_getter'
require_relative 'app'
require_relative 'search_client'
require_relative 'indexer'

module CfDeployment
  class BlueGreen
    def initialize(account)
      @account = account
    end

    def deploy
      @account.login

      getter = CfGetter.new(@account)
      @app = App.new(@account, getter)

      puts ""
      puts "Currently running app is: #{app.current_app_name}"
      puts "Deploying to app: #{app.updating_app_name}"
      puts ""

      extract_site_source

      switch_robots
      
      indexer = Indexer.new(File.expand_path('site-source/final_app/public'))
      @search_client = SearchClient.new(indexer, getter, app.current_app)
      search_client.index_site

      cf_push(app.updating_app_name, @account.routes.first, search_client.search_service)

      map_routes(app.updating_app_name, @account.routes)

      search_client.swap_indices

      stop_app(app.current_app_name)
    end

    # robots.txt used by our books keeps staging sites from being indexed by search engines. 
    # In prod, we want to use a different robots.txt file, 'prod_robots.txt', if it exist 
    def switch_robots
      if ENV['DEPLOY_ENV'] == 'production'
        puts "Removing robots.txt..."
        system("rm site-source/final_app/public/robots.txt")
        puts "Renaming prod_robots.txt to robots.txt..."
        system("mv site-source/final_app/public/prod_robots.txt site-source/final_app/public/robots.txt")
      end
      puts system("ls site-source/final_app/public | grep robots.txt") ? "Robots.txt are present" : "No robots.txt exists."
    end

    def cleanup
      if app
        stop_app(app.updating_app_name)
        start_app(app.current_app_name)
      end
      if search_client
        search_client.delete_index(search_client.updating_index)
      end
    end

    private

    attr_reader :app, :search_client

    def extract_site_source
      if system("tar xzf site-source/*.tar.gz -C site-source")
        puts "extracted to site-source/final_app"
        puts `du -sh site-source/final_app`
      else
        raise "Failed to extract site source"
      end
    end

    def cf_push(updating_app_name, target_route, search_service)
      push_cmd = %Q{cf push #{updating_app_name} -b https://github.com/cloudfoundry/ruby-buildpack#v1.6.28 -p site-source/final_app -d #{target_route['domain']} }

      unless target_route['hostname'] == ''
        push_cmd << %Q{ -n #{target_route['hostname']} }
      end

      if target_route['path'] != ''
        push_cmd << " --route-path \"/#{target_route['path']}\""
      end

      if search_service
        push_cmd << ' --no-start'
      end

#    if updating_app_name == "docs-pcfservices-blue" || "docs-pcfservices-green"
#      push_cmd << ' -m 512M'
#    end

      puts push_cmd
      unless system(push_cmd)
        raise "Failed to push"
      end

      if search_service
        unless system('cf', 'bind-service', updating_app_name, search_service)
          raise "Failed to bind #{search_service} to #{updating_app_name}"
        end

        start_app(updating_app_name)
      end
    end

    def map_routes(updating_app_name, routes)
      routes.each do |route|
        map_route_cmd = %Q{cf map-route #{updating_app_name} #{route['domain']}}

        if route['hostname'] != ''
          map_route_cmd << %Q{ -n "#{route['hostname']}"}
        end

        if route['path'] != ''
          map_route_cmd << %Q{ --path "/#{route['path']}"}
        end

        puts map_route_cmd
        unless system(map_route_cmd)
          raise "Failed to map route #{route['hostname']}.#{route['domain']}/#{route['path']}"
        end
      end
    end

    def start_app(app_name)
      unless system("cf start #{app_name}")
        raise "Failed to start"
      end
    end

    def stop_app(current_app_name)
      3.times do
        unless system("cf stop #{current_app_name}")
          raise "Failed to stop #{current_app_name}"
        end


        12.times do
          sleep(5)

          output = `cf app #{current_app_name}`

          if output.include?('There are no running instances of this app.')
            puts "\nApp #{current_app_name} has shut down successfully."
            return
          end
        end
      end

      raise "Unable to stop #{current_app_name}"
    end
  end
end
