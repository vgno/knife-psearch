# psearch.rb: A knife plugin for the Partial Search API
#
# Note that this is a Beta feature of Opscode Hosted Chef
# and that it's interface may changed based on user feedback.
#
# This plugin is net yet officially supported by Opscode
 
class Psearch < Chef::Knife
  banner "knife psearch INDEX SEARCH (Optional: -a attributes)"
 
  deps do
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
  :description => "When using -g do not list nodes that does not have the attribute you are grouping on set.",
  :default => false

  option :quiet,
  :short => "-q",
  :long => "--quiet",
  :description => "Do not print empty attributes.",
  :default => false

  option :count,
    :short => "-c",
    :long  => "--count",
    :description => "Just show the node count when grouping.",
    :default => false

  option :id_only,
    :short  => "-i",
    :long   => "--id-only",
    :description => "Show only the ID of matching objects.",
    :default  => false
 
  def run
    @index, @search = @name_args
    args_hash = {}
    args_hash[:keys] = build_key_hash
    args_hash[:sort] = config[:sort]
    args_hash[:start] = config[:start]
    args_hash[:rows] = config[:rows]
    
    results = Chef::PartialSearch.new.search(@index, @search, args_hash)

    if (config[:id_only] && results.first.length > 0)
      $stderr.puts "Found #{results.first.length} matches.\n\n"
      results.first.map { |res| puts res['name'] }
    elsif (config[:group])
      outputResults(groupResults(results.first))
    else
      output results.first
    end
  end

  def groupResults(itemList)
    attrName = config[:group]
    matches = Hash.new {|h,k| h[k] = [] }
    noMatch = Array.new

    cnt_matches = 0
    cnt_noMatch = 0

    itemList.each do |item|
      attrVal = item[attrName]
      nodeName = item['name']

      if attrVal.nil?
        cnt_noMatch += 1
        noMatch << nodeName
        next
      end

      cnt_matches += 1

      if config[:attribute]
        itemAttributes = Hash.new

        item.each do |itemAttr|
          if itemAttr.first != attrName && itemAttr.first != "name"
            (config[:quiet] && itemAttr[1].nil?) && next
            itemAttributes[itemAttr[0]] = itemAttr[1]
          end
        end

        matches[attrVal] << { nodeName => itemAttributes }
      else
        matches[attrVal] << nodeName
      end
    end

    {
      :attrName   => attrName, :matches    => matches, :noMatch    => noMatch,
      :matchCnt   => cnt_matches, :noMatchCnt => cnt_noMatch
    }
  end

  def outputResults(result)
    ui.msg("Found #{result[:matchCnt]} nodes with #{result[:attrName]} attribute set.\n")

    !config[:no_match] && result[:noMatchCnt] > 0 &&
        ui.msg("Found #{result[:noMatchCnt]} non matching nodes.\n")

    ui.msg("\n")

    result[:matches].each do |nn|
      if config[:count]
        output({nn.first => result[:matches][nn.first].size})
        next
      end

      title = "#{nn.first} (#{nn[1].size} node"
      title += nn[1].size > 1 ? "s)" : ")"

      output({title => nn.drop(1)})
      ui.msg("\n")
    end

    if !config[:no_match] && result[:noMatchCnt] > 0
      if config[:count]
        output ({"Not matching" => result[:noMatchCnt]})
      else
        title = "Non matching (#{result[:noMatchCnt]} node"
        title +=  result[:noMatchCnt] > 1 ? "s)" : ")"
        output({title => result[:noMatch]})
      end
    end
  end

  def build_key_hash
    key_hash = {}

    if config[:group]
      key_hash[config[:group]] = config[:group].split(".")
    end

    if config[:attribute]
      specs = config[:attribute].split(',')

      specs.each do |spc|
        key_hash[spc] = spc.split(".")
      end
    end

    key_hash["name"] = [ "name" ] unless key_hash.has_key?("name")
    key_hash
  end
end
