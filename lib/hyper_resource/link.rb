require 'uri_template'
require 'hyper_resource/modules/http'

class HyperResource

  ## HyperResource::Link is an object to represent a hyperlink and its
  ## URL or body parameters, and to encapsulate HTTP calls involving this
  ## link.  Links are typically created by HyperResource, not by end users.
  ##
  ## HTTP method calls return the response as a HyperResource (or subclass)
  ## object.  Calling an unrecognized method on a link will automatically
  ## load the resource pointed to by this link, and repeat the method call
  ## on the resource object.
  ##
  ## A HyperResource::Link requires the resource it is based upon to remain
  ## in scope.  In practice this is rarely a problem, as links are almost
  ## always accessed through the resource object.

  class Link

    include HyperResource::Modules::HTTP

    ## The URL the base_href appends to_s
    attr_accessor :base_url

    ## The literal href of this link; may be templated.
    attr_accessor :base_href

    ## An optional name describing this link.
    attr_accessor :name

    ## `true` if this link's href is a URI Template, `false` otherwise.
    attr_accessor :templated

    ## A hash of URL or request body parameters.
    attr_accessor :params

    ## Default HTTP method for implicit loading.
    attr_accessor :default_method

    ## The resource from which this link originates.
    attr_accessor :resource

    ## Returns a link based on the given resource and link specification
    ## hash.  `link_spec` keys are: `href` (string, required), `templated`
    ## (boolean), `params` (hash), and `default_method` (string, default
    ## `"get"`).
    def initialize(resource, link_spec={})      
      unless link_spec.kind_of?(Hash)
        raise ArgumentError, "link_spec must be a Hash (got #{link_spec.inspect})"
      end
      link_spec = Hash[ link_spec.map{|(k,v)| [k.to_s, v]} ] ## stringify keys

      self.resource = resource
      self.base_url = link_spec['base_url'] || resource.root
      self.base_href = link_spec['href']
      self.name = link_spec['name']
      self.templated = !!link_spec['templated']
      self.params = link_spec['params'] || {}
      self.default_method = link_spec['method'] || 'get'
    end

    ## Returns this link's href, applying any URI template params.
    def href
      if self.templated
        filtered_params = self.resource.outgoing_uri_filter(params)
        URITemplate.new(self.base_href).expand(filtered_params)
      else
        self.base_href
      end
    end

    ## Returns this link's fully resolved URL, or nil if `base_url`
    ## or `href` are malformed.
    def url
      begin
        base_path = URI.parse(self.base_url).path
        if base_path.empty?
          URI.join(self.base_url, self.href.to_s).to_s
        else
          URI.join(self.base_url, base_path, self.href.to_s.sub('/', '')).to_s
        end
      rescue StandardError
        nil
      end
    end

    ## Returns a new scope with the given params; that is, returns a copy of
    ## itself with the given params applied.
    def where(params)
      params = Hash[ params.map{|(k,v)| [k.to_s, v]} ]
      self.class.new(self.resource,
                     'base_url' => self.base_url,
                     'href' => self.base_href,
                     'name' => self.name,
                     'templated' => self.templated,
                     'params' => self.params.merge(params),
                     'method' => self.default_method)
    end

    ## Unrecognized methods invoke an implicit load of the resource pointed
    ## to by this link.  The method call is then repeated on the returned
    ## resource.
    def method_missing(method, *args)
      self.send(default_method || :get).send(method, *args)
    end

  end
end

