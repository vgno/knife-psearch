# psearch.rb: A knife plugin for the Partial Search API
# Author: Ole Fredrik Skudsvik <oles@vg.no> 

class Psearch < Chef::Knife
    banner "knife psearch INDEX SEARCH (Optional: -a attributes)"

    deps do
        require File.join(File.dirname(__FILE__), 'partial_search.rb')
        require 'pp'
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

    option :compare,
        :short => "-m attr1:attr2",
        :long  => "--compare attr1:attr2",
        :description => "Compare two attributes."

    def printObject data, attrName=nil, indentLevel=1
        indent = indentLevel.times.collect{}.join(' ')

        if data.is_a?(Hash)
            data.each do |k,v|
                if v.is_a?(String)
                    indent='' if (attrName.nil?)
                    puts "\e[1;32;40m#{indent} #{k}:\e[0m #{v}"
                    next
                else
                    puts "\e[1;32;40m#{indent}#{k}:\e[0m"
                    printObject v, k, (indentLevel + 1)
                end
            end
        elsif data.is_a?(Array)
            data.each do |v|
                printObject v, nil, indentLevel
            end
        else
            if attrName.nil?
                puts "\e[1;32;40m#{indent}\e[0m #{data}"
            else
                puts "\e[1;32;40m#{indent}#{attrName}:\e[0m #{data}"
            end
        end
    end

    def run
        @index, @search = (@name_args.size == 1) ? ["node", @name_args.first] : @name_args; 
        
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
            groupResults results.first
        elsif config[:compare]
            compareAttributes(results.first)
        else
            printObject results.first
        end
    end

    def groupArr arr, props
        groups = arr.group_by do |x| 
            if x[props.first].nil?
                :noMatch
            else
                x[props.first]
            end
        end

        groups.each do |k,v|
            v.each do |p|
                if p.key?('name') && config[:attribute].nil?

                end
                p.delete(props.first) 
            end
        end

        return groups if props.count == 1

        groups.merge(groups) do |group, elements|
            groupArr(elements, props.drop(1))
        end
    end

    def groupResults(itemList)
        groupList = config[:group].split(",")

        if config[:attribute]
            groupList << "name"
        end

        res = groupArr(itemList, groupList)
        countMap = getCounts res
        totalMatching = (countMap.values.inject(:+) - countMap[:noMatch].to_i)

        puts "Found #{totalMatching.to_i} matching nodes."
        puts "Found #{countMap[:noMatch].to_i} non matching nodes.\n\n"

        if config[:count]
            countMap.delete(:noMatch) if config[:no_match]
            countMap.map { |k,v| puts "#{k}: #{v}" }
            exit
        end

        res.each do |k, v|
            next if (k == :noMatch)
            key = "#{k} (#{countMap[k]} node"
            key += (countMap.key?(k) && countMap[k] > 1) ? "s)" : ")"

            printObject( { key => v } )
            puts "\n"
        end

        if !config[:no_match] && !res[:noMatch].nil? 
            printObject({"Non matching (#{countMap[:noMatch].to_i} nodes)" => res[:noMatch]})
        end
    end

    def getCounts arr, countHash = {}, groupName=nil
        groupList = config[:group].split(",")

        arr.each do |x,v|
            # FIXME: We should not be dependant on checking the groupList parameter.
            if groupList.size == 1
                countHash[x] = v.size
                next
            end

            if v.first.kind_of?(Array) # We have a group.
                getCounts(v, countHash, x)
                next
            end

            if v.kind_of?(Array) && x != "" # We have an entry.
                countHash[groupName] = countHash.key?(groupName) ? (countHash[groupName] + v.size) : v.size
            end
        end

        countHash
    end

    def compareAttributes(itemList)
        cmp1, cmp2 = config[:compare].split(':')
        fail "Usage: -m attr1:attr2" if cmp1.nil? || cmp2.nil?

        matches = Array.new
        nonMatches = Array.new

        itemList.each do |item|

            if item[cmp1] == item[cmp2]
                matches << "#{item['name']} (#{item[cmp1]}:#{item[cmp2]})"
            else
                nonMatches << "#{item['name']} (#{item[cmp1]}:#{item[cmp2]})"

            end
        end 

        printObject({ "#{cmp1} == #{cmp2}" => matches })
        puts
        printObject({ "#{cmp1} != #{cmp2}" => nonMatches })
    end

    def build_key_hash
        key_hash = {}

        if config[:group]
            config[:group].split(",").each do |k|
                key_hash[k] = k.split(".")
            end
        end

        if config[:attribute]
            specs = config[:attribute].split(',')

            specs.each do |spc|
                key_hash[spc] = spc.split(".")
            end
        end

        # FIXME: Code duplication.
        if config[:compare]
            specs = config[:compare].split(':')

            specs.each do |spc|
                key_hash[spc] = spc.split(".")
            end
        end

        key_hash["name"] = [ "name" ] unless key_hash.has_key?("name")
        key_hash
    end
end
