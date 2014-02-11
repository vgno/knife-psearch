#knife-psearch
*Partitial search plugin for knife with support for grouping matches based on attributes.*

##Example searches

###Search and group results

**List all nodes with PHP installed and group output based on PHP version**

`knife psearch node "name:*" -g languages.php.version`


**Same search, but also include servers which do not have the languages.php.version attribute set**

  `knife psearch node "name:*" -g languages.php.version -n`

###Standard partitial searches

By default psearch will return the node name on all searches.
You can specify additional attributes to include with the -a flag.
Multiple attributes is separated by a comma.

**Show ipaddress and roles on all nodes**

`knife psearch node "name:*" -a ipaddress,roles`

##Installation

Copy psearch.rb, partitial_search.rb to $HOME/.chef/plugins
