require 'webmock/rspec'

require_relative '../../cf_deployment/cf_getter'

module CfDeployment
  describe CfGetter do
    before do
      WebMock.disable_net_connect!
    end

    after do
      WebMock.allow_net_connect!
    end

    let(:account) do
      double(:account, {
        endpoint: 'https://api.run.example.com',
        access_token: 'ACCESSIBLE_ACCESS_TOKEN',
        organization: 'coolest-org',
        space: 'wicked-space'
      })
    end
    let(:getter) { CfGetter.new(account) }

    it 'makes a request with authorization' do
      stub_request(:get, 'https://api.run.example.com/foo/bar').to_return(body: '{}')
      getter.request('/foo/bar')

      expect(WebMock).to have_requested(:get, 'https://api.run.example.com/foo/bar').with({
        headers: {
          'Authorization' => 'ACCESSIBLE_ACCESS_TOKEN',
          'Accept' => 'application/json',
          'Host' => 'api.run.example.com'
        }
      })
    end

    it 'returns parsed JSON' do
      stub_request(:get, 'https://api.run.example.com/foo/bar').to_return(body: '{"foo": "bar", "baz": "quux"}')
      result = getter.request('/foo/bar')

      expect(result).to eq({
        'foo' => 'bar',
        'baz' => 'quux'
      })
    end

    it 'query strings' do
      stub_request(:get, 'https://api.run.example.com/foo/bar?some-org=awesome-org').to_return(body: '{"foo": "bar", "baz": "quux"}')
      result = getter.request('/foo/bar', 'some-org=awesome-org')

      expect(result).to eq({
        'foo' => 'bar',
        'baz' => 'quux'
      })

      expect(WebMock).to have_requested(:get, 'https://api.run.example.com/foo/bar?some-org=awesome-org')
    end

    it 'fails when the request fails' do
      stub_request(:get, 'https://api.run.example.com/foo/bar').to_return(status: [401, 'Ooops'], body: '{}')

      expect {
        getter.request('/foo/bar')
      }.to raise_error(Net::HTTPServerException)
    end

    context 'paginated data' do
      it 'gets resources that have only one page' do
        stub_request(:get, 'https://api.run.example.com/foo/bar').to_return(body: JSON.dump({
          resources: [
            'some stuff',
            'blah'
          ],
          next_url: nil
        }))
        response = getter.get_all_pages('/foo/bar')

        expect(response).to eq(['some stuff', 'blah'])
      end

      it 'gets all the pages' do
        stub_request(:get, 'https://api.run.example.com/foo/bar').to_return(body: JSON.dump({
          resources: [
            'other stuff',
            'more'
          ],
          next_url: '/foo/bar/2'
        }))
        stub_request(:get, 'https://api.run.example.com/foo/bar/2').to_return(body: JSON.dump({
          resources: [
            'second page',
            'second more'
          ],
          next_url: '/foo/bar/3'
        }))
        stub_request(:get, 'https://api.run.example.com/foo/bar/3').to_return(body: JSON.dump({
          resources: [
            'third page',
            'third more'
          ],
          next_url: nil
        }))
        response = getter.get_all_pages('/foo/bar')

        expect(response).to eq(['other stuff', 'more', 'second page', 'second more', 'third page', 'third more'])
      end

      it 'handles query strings' do
        stub_request(:get, 'https://api.run.example.com/foo/bar?baz=quux').to_return(body: JSON.dump({
          resources: [
            'other stuff',
            'more'
          ],
          next_url: '/foo/bar?baz=quux&page=2'
        }))
        stub_request(:get, 'https://api.run.example.com/foo/bar?baz=quux&page=2').to_return(body: JSON.dump({
          resources: [
            'second page',
            'second more'
          ],
          next_url: '/foo/bar?baz=quux&page=3'
        }))
        stub_request(:get, 'https://api.run.example.com/foo/bar?baz=quux&page=3').to_return(body: JSON.dump({
          resources: [
            'third page',
            'third more'
          ],
          next_url: nil
        }))
        response = getter.get_all_pages('/foo/bar', 'baz=quux')

        expect(response).to eq(['other stuff', 'more', 'second page', 'second more', 'third page', 'third more'])
      end
    end
  end
end
