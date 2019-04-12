require_relative '../../cf_deployment/page'

module CfDeployment
  describe Page do
    it 'extracts the content from the `main` element' do
      html = <<-HTML
<div>
unindexed
<main>          indexed


</main>
</div>
      HTML

      page = Page.new('', html)
      expect(page.to_h[:text]).to eq('indexed')
      expect(page.to_h[:title]).to eq('')
    end

    it 'extracts the title' do
      html = <<-HTML
<div>
<main>
<h1 class='title-container'>


some-title</h1>
indexed stuff
</main>
</div>
      HTML

      page = Page.new('', html)
      expect(page.to_h[:title]).to eq('some-title')
    end

    it 'extracts and concatenates h2 and h3' do
      html = <<-HTML
<div>
<main>
<h2 id="this-is-an-h2"><a id='heyo'></a>Random H2</h2>
<h3 id="and-an-h3"><a id='what'></a>Now an H3</h3>
<h2 id="one-more-h2"><a id='ponyo'></a>One more</h2>
</main>
</div>

      HTML

      page = Page.new('', html)
      expect(page.to_h[:headings]).to eq('Random H2 Now an H3 One more')
    end

    it 'removes the header' do
      html = <<-HTML
<div>
<main>
<header>
<div class="embedded-searchbar">Don't include this stuff</div>
</header>
But include this
</main>
</div>
      HTML

      page = Page.new('', html)
      expect(page.to_h[:text]).to eq('But include this')
    end

    it 'removes js-quick-links' do
      html = <<-HTML
<div>
<main>
Some included content
<div id='js-quick-links'>no including!</div>
</main>
</div>
      HTML

      page = Page.new('', html)
      expect(page.to_h[:text]).to eq('Some included content')
    end

    it 'removes the repo-link' do
      html = <<-HTML
<div>
<main>
Some included content
<a id='repo-link'>no including!</a>
</main>
</div>
      HTML

      page = Page.new('', html)
      expect(page.to_h[:text]).to eq('Some included content')
    end

    it 'extracts the product info' do
      html = <<-HTML
<div>
  <main>
<header>
    <div class="embedded-searchbar">
      <input name="product_name" value="product" />
      <input name="product_version" value="me" />
    </div>
</header>
  </main>
</div>
      HTML
      page = Page.new('', html)
      expect(page.to_h[:product_name]).to eq('product')
      expect(page.to_h[:product_version]).to eq('me')
    end

    it 'extracts the product info with no version' do
      html = <<-HTML
<div>
  <main>
<header>
    <div class="embedded-searchbar">
      <input name="product_name" value="product" />
    </div>
</header>
  </main>
</div>
      HTML
      page = Page.new('', html)
      expect(page.to_h[:product_name]).to eq('product')
      expect(page.to_h[:product_version]).to be_nil
    end

    it 'ignores product info not in the local header' do
      html = <<-HTML
<div>
  <main>
    <input name="product_name" value="product" />
    <input name="product_version" value="me" />
    <div class="local-header">
    </div>
  </main>
</div>
      HTML
      page = Page.new('', html)
      expect(page.to_h[:product_name]).to be_nil
      expect(page.to_h[:product_version]).to be_nil
    end

    it 'ignores product info not in the header but uses the real stuff' do
      html = <<-HTML
<div>
  <main>
    <input name="product_name" value="product" />
    <input name="product_version" value="me" />
    <header>
      <div class="embedded-searchbar">
        <input name="product_name" value="real_product" />
        <input name="product_version" value="real_me" />
      </div>
    </header>
  </main>
</div>
      HTML
      page = Page.new('', html)
      expect(page.to_h[:product_name]).to eq('real_product')
      expect(page.to_h[:product_version]).to eq('real_me')
    end

    it 'has a url' do
      page = Page.new('product/things/stuff.html', '')
      expect(page.to_h[:url]).to eq('/product/things/stuff.html')
    end

    it 'extracts a summary from the first 20 words' do
      html = <<-HTML
<div>
<main>This is some cool content with lots and lots of text.<br/>
It probably wraps lines
<br/>
And has lots of strange things going on.</main>
</div>
      HTML

      page = Page.new('', html)
      expect(page.to_h[:summary]).to eq('This is some cool content with lots and lots of text. It probably wraps lines And has lots of strange')
    end
  end
end
