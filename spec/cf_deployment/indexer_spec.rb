require_relative '../../cf_deployment/indexer'

module CfDeployment
  describe Indexer do
    class FakePage
      def to_h
         {text: ""}
      end
    end

    subject(:indexer) { Indexer.new("some_path") }

    it { should be_excluded_path('index.html') }
    it { should be_excluded_path('404.html') }
    it { should be_excluded_path('owners.html') }
    it { should_not be_excluded_path('pwners.html') }
    it { should_not be_excluded_path('howners.html') }
    it { should_not be_excluded_path('403.html') }
    it { should_not be_excluded_path('windex.html') }

    it { should be_excluded_path('stuff/README.html') }
    it { should_not be_excluded_path('stuff/README.htmlz') }

    it { should be_excluded_path('subnavs/some_file.html') }
    it { should_not be_excluded_path('other_dir/some_file.html') }
    it { should_not be_excluded_path('subnavstuff.html') }

    it { should_not be_excluded_path('subnav/index.html') }
    it { should_not be_excluded_path('subnav/404.html') }
    it { should_not be_excluded_path('subnav/owners.html') }

    it "should strip index.html from paths where the page is exactly index.html" do
      #we think this was intended to make the url prettier.
      fake_paths = ["cool_story/index.html",
                    "cool_story2/dont-mangle-my-index.html"]
      expect(Dir).to receive(:glob).and_return(fake_paths)
      allow(File).to receive(:read).and_return("some file contents")
      fake_page = FakePage.new
      expect(Page).to receive(:new).with("cool_story/", "some file contents").and_return(fake_page)
      expect(Page).to receive(:new).with("cool_story2/dont-mangle-my-index.html", "some file contents").and_return(fake_page)
      indexer.parse_pages

    end
  end
end
