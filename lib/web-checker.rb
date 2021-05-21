require 'addressable'
require 'http'
require 'nokogiri'
require 'nokogumbo'
require 'path'

class WebChecker

  SchemasDir = Path.new(__FILE__).dirname / 'web-checker' / 'schemas'
  SchemaNames = {
    'feed' => 'atom',
    'urlset' => 'sitemap',
  }

  class Error < Exception; end

  def initialize(site_uri:, site_dir:)
    @site_uri = Addressable::URI.parse(site_uri)
    @site_dir = Path.new(site_dir)
    @schemas = {}
    @seen = {}
    @files = []
  end

  def check
    # get/parse robots
    # get/parse sitemap
    check_uri(@site_uri)
  end

  def check_uri(uri)
    uri = Addressable::URI.parse(uri)
    uri.normalize!
    return if seen?(uri)
    return unless http?(uri)
    is_local = local?(uri)
    ;;warn "CHECKING: #{uri}"
    response = HTTP.get(uri)
    # ;;pp(response: response)
    @seen[uri] = true
    case response.code
    when 200...300
      if is_local
        data = response.body.to_s
        case (type = response.headers['Content-Type'])
        when 'text/html', 'text/xml', 'application/xml'
          check_markup(uri, data)
        when 'text/css'
          check_css(uri, data)
        when %r{^image/}, 'application/javascript'
          # ignore
        else
          ;;warn "skipping unknown resource type: #{uri} (#{type})"
        end
      end
    when 300...400
      redirect_uri = Addressable::URI.parse(response.headers['Location'])
      check_uri(uri + redirect_uri)
    when 404
      raise Error, "URI not found: #{uri}"
    else
      raise Error, "Bad status: #{response.inspect}"
    end
  end

  def check_markup(uri, data)
# ;;warn "validating markup: #{uri}"
    doc = case data
    when /^<\?xml/i
      Nokogiri::XML(data) { |c| c.strict }
    when /^<!DOCTYPE html>/i
      Nokogiri::HTML5(data, max_errors: -1)
    else
      Nokogiri::HTML(data) { |c| c.strict }
    end
    unless doc.errors.empty?
      show_errors(doc.errors)
      raise Error, "markup parsing failed"
    end
    if (schema_name = SchemaNames[doc.root.name])
      schema_file = (SchemasDir / schema_name).add_extension('.xsd')
      schema = (@schemas[schema_file] ||= Nokogiri::XML::Schema(schema_file.open))
      validation_errors = schema.validate(doc)
      unless validation_errors.empty?
        show_errors(validation_errors)
        raise Error, "schema validation failed"
      end
    end
    doc.xpath('//@href | //@src').each do |elem|
      check_uri(uri + elem.value)
    end
  end

  def show_errors(errors)
    errors.each do |error|
      warn "#{error} [line #{error[:line]}, column #{error[:column]}]"
    end
  end

  def check_css(uri, css)
    css.gsub(/\burl\(\s*["'](.*?)["']\s*\)/) do
      check_uri(uri + $1)
    end
  end

  def http?(uri)
    !uri.scheme || %w[http https].include?(uri.scheme)
  end

  def local?(uri)
    (!uri.scheme && !uri.host) ||
      (uri.scheme == @site_uri.scheme && uri.host == @site_uri.host && uri.port == @site_uri.port)
  end

  def seen?(uri)
    @seen[uri]
  end

  def report
    unless @files.empty?
      puts "\t" + "unreferenced files:"
      @files.sort.each do |path|
        puts "\t\t" + path.to_s
      end
    end
  end

end