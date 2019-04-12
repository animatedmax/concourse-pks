module CfDeployment
  class App
    def initialize(account, getter)
      @account = account
      @getter = getter
    end

    def current_app_name
      current_app[:name]
    end

    def current_app
      unless @current_app
        target_route = account.routes.first
        apps = running_apps_for_route(target_route_guid(target_route))

        if apps.size == 0
          raise "No apps mapped to route: #{target_route['hostname']}.#{target_route['domain']}/#{target_route['path']}"
        elsif apps.size > 1
          raise "Too many apps mapped to route! Apps: #{apps.map { |app| app[:name] }.join(', ')}"
        end

        @current_app = apps.first
      end

      @current_app
    end

    def updating_app_name
      @updating_app_name ||= current_app_name.sub(/(?<=-)(green|blue)\z/, {'green' => 'blue', 'blue' => 'green'})
    end

    private

    attr_reader :account, :getter

    def target_route_guid(target_route)
      org_response = getter.request('/v2/organizations', "q=name%3A#{account.organization}")
      org_guid = org_response.fetch('resources').first.fetch('metadata').fetch('guid')

      org_domains = getter.get_all_pages("/v2/organizations/#{org_guid}/private_domains")

      domains = org_domains.each.with_object({'fb6bd89f-2ed9-49d4-9ad1-97951a573135' => 'cfapps.io'}) do |domain_data, domains|
        domains[domain_data.fetch('metadata').fetch('guid')] = domain_data.fetch('entity').fetch('name')
      end

      space_response = getter.request("/v2/organizations/#{org_guid}/spaces", "q=name%3A#{account.space}")
      space_guid = space_response.fetch('resources').first.fetch('metadata').fetch('guid')

      space_routes = getter.get_all_pages("/v2/spaces/#{space_guid}/routes")

      target_route['guid'] = domains.keys.detect { |guid| domains[guid] == target_route['domain'] }
      first_route_data = space_routes.detect do |route|
        route_info = route.fetch('entity')
        route_info.fetch('domain_guid') == target_route['guid'] &&
          route_info.fetch('host') == target_route['hostname'] &&
          route_info.fetch('path').sub(/\A\//, '') == target_route['path']
      end

      raise "Route: #{target_route['hostname']}.#{target_route['domain']}/#{target_route['path']} not found" if first_route_data.nil?

      first_route_data.fetch('metadata').fetch('guid')
    end

    def running_apps_for_route(route_guid)
      apps_response = getter.request("/v2/routes/#{route_guid}/apps")

      apps_response.fetch('resources').reject do |resource|
        resource['entity']['state'] == 'STOPPED'
      end.map do |resource|
        {
          name: resource.fetch('entity').fetch('name'),
          guid: resource.fetch('metadata').fetch('guid')
        }
      end
    end
  end
end
