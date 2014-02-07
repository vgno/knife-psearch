#
# Author:: Ole Fredrik Skudsvik <oles@vg.no> 
# Based of knife search plugin by Adam Jacob <adam@opscode.com>
# Copyright:: Copyright (c) 2009 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require 'chef/knife/core/node_presenter'

class Chef
  class Knife
    class Group < Knife

      deps do
        require 'chef/node'
        require 'chef/environment'
        require 'chef/api_client'
        require 'chef/search/query'
      end

      include Knife::Core::NodeFormattingOptions

      banner "knife group INDEX QUERY (options)"

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

      option :run_list,
        :short => "-r",
        :long => "--run-list",
        :description => "Show only the run list"

      option :id_only,
        :short => "-i",
        :long => "--id-only",
        :description => "Show only the ID of matching objects"

      option :query,
        :short => "-q QUERY",
        :long => "--query QUERY",
        :description => "The search query; useful to protect queries starting with -"

      option :no_match,
      	:short => "-n",
      	:long => "--nomatch",
      	:description => "Also print nodes that doesn't match you attribute group.",
      	:default => false
 

      def run
        read_cli_args
        fuzzify_query

        if @type == 'node'
          ui.use_presenter Knife::Core::NodePresenter
        end

        q = Chef::Search::Query.new
        escaped_query = URI.escape(@query,
                           Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

        result_items = []
        result_count = 0

        rows = config[:rows]
        start = config[:start]
        begin
          q.search(@type, escaped_query, config[:sort], start, rows) do |item|
            formatted_item = format_for_display(item)
            result_items << formatted_item
            result_count += 1
          end
        rescue Net::HTTPServerException => e
          msg = Chef::JSONCompat.from_json(e.response.body)["error"].first
          ui.error("knife search failed: #{msg}")
          exit 1
        end

        if ui.interchange?
          output({:results => result_count, :rows => result_items})
        else
          groupOutput result_count, result_items
        end
        end

        def groupOutput(resCount, itemList)

        	grouped_result = Hash.new {|h,k| h[k] = [] }

        	itemList.each do |item|
        		nodeName 	  = item.keys[0]
        		nodeAttribute = item[item.keys[0]][config[:attribute]]

        		if (nodeAttribute.nil?)
        			nodeAttribute = :noMatch
        		end

        		grouped_result[nodeAttribute] << nodeName
        	end


        	if (config[:no_match] == false && grouped_result.has_key?(:noMatch)) 
        		resCount -= grouped_result[:noMatch].size
        	end

        	ui.msg "#{resCount} items found"
        	ui.msg("\n")

        	grouped_result.each do |attribute|
        		if (attribute[0] != :noMatch)
        			output attribute
        			ui.msg("\n");
        		end
        	end

        	if (config[:no_match] == true)
        		ui.msg("Nodes without grouping attribute set:\n");
        		ui.msg("\n");
        		grouped_result[:noMatch].each do |nn|
        			output nn
        		end
        	end
        end

        def read_cli_args
        if config[:query]
          if @name_args[1]
            ui.error "please specify query as an argument or an option via -q, not both"
            ui.msg opt_parser
            exit 1
          end
          @type = name_args[0]
          @query = config[:query]
        else
          case name_args.size
          when 0
            ui.error "no query specified"
            ui.msg opt_parser
            exit 1
          when 1
            @type = "node"
            @query = name_args[0]
          when 2
            @type = name_args[0]
            @query = name_args[1]
          end
        end
      end

      def fuzzify_query
        if @query !~ /:/
          @query = "tags:*#{@query}* OR roles:*#{@query}* OR fqdn:*#{@query}* OR addresses:*#{@query}*"
        end
      end

    end
  end
end