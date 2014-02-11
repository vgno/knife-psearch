# psearch.rb: A knife plugin for the Partial Search API
#
# Note that this is a Beta feature of Opscode Hosted Chef
# and that it's interface may changed based on user feedback.
#
# This plugin is net yet officially supported by Opscode
 
class Psearch < Chef::Knife
  banner "knife psearch INDEX SEARCH (Optional: -a attributes)"
 
  deps do
    # Note, this requires the partial_search.rb library currently
    # only available in the partial search cookbook
    # https://github.com/opscode/partial_search
    require File.join(File.dirname(__FILE__), 'partial_search.rb')
  end
 
  option :sort,
  :short => "-o SORT",
  :long => "--sort SORT",
  :description => "The order to sort the results in",
  :default => nil
 
  option :start,
  :short => "-b ROW",
  :long => "--start ROW",
  :description => "The row to start returning results at",
  :default => 0,
  :proc => lambda { |i| i.to_i }
 
  option :rows,
  :short => "-R INT",
  :long => "--rows INT",
  :description => "The number of rows to return",
  :default => 1000,
  :proc => lambda { |i| i.to_i }
 
  option :attribute,
  :short => "-a ATTR",
  :long => "--attribute ATTR",
  :description => "Show only one attribute"

  option :group,
  :short => "-g ATTR",
  :long => "--group ATTR",
  :description => "Search for nodes with attribute ATTR and group based on it."

  option :no_match,
  :short => "-n",
  :long => "--nomatch",
  :description => "Also print nodes that doesn't match you attribute group.",
  :default => false
 
  def run
    @index, @search = @name_args
    args_hash = {}
    args_hash[:keys] = build_key_hash
    args_hash[:sort] = config[:sort]
    args_hash[:start] = config[:start]
    args_hash[:rows] = config[:rows]
    
    if (config[:group])
      
      results = Chef::PartialSearch.new.search(@index, @search, 
        :keys => { 
        config[:group] => config[:group].split("."),
        'name' => ['name']
        })

      groupOutput(results.first)
    else
      results = Chef::PartialSearch.new.search(@index, @search, args_hash)
      output results.first
    end
  
  end

  def groupOutput(itemList)

    attrName = config[:group]

    matches = Hash.new {|h,k| h[k] = [] }
    noMatch = Array.new

    cnt_matches = 0
    cnt_noMatch = 0

    itemList.each do |item|
      attrVal = item[attrName]
      nodeName = item['name']

      if (attrVal.nil?)
        cnt_noMatch += 1
        noMatch << nodeName
        next
      end

      cnt_matches += 1
      matches[attrVal] << nodeName
    end

    ui.msg("Found #{cnt_matches} nodes with #{attrName} attribute set.\n")
    (config[:no_match] && cnt_noMatch > 0) ? ui.msg("Found #{cnt_noMatch} non-matching nodes.\n") : ""

    ui.msg("\n")

    matches.each do |nn|
      output nn
      ui.msg("\n")
    end

    if (config[:no_match] && noMatch.size > 0)
      ui.msg "Non matching nodes: "
      noMatch.each do |nm|
        ui.msg nm
      end
    end

end
 
  def build_key_hash
    key_hash = {}

    if (config[:attribute])
      specs = config[:attribute].split(',')

      specs.each do |spc|
        key_hash[spc] = spc.split(".")
      end
    end

    # This seems like a sane default.  The results without the name
    # are usually not what we want.
    key_hash["name"] = [ "name" ] unless key_hash.has_key?("name")
    key_hash
  end
end
