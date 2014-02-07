knife-group - Knife plugin to group Chefqueries based on attributes.
- Based on knife search

Example search:
  knife group "name:*" -a languages.php.version

Same search, but also include servers which do not have the search attribute set:
  knife group "name:*" -a languages.php.version -n

Installation:
  Copy group.rb to $HOME/.chef/plugins/group.rb
