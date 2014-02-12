#knife-psearch
*Partial search plugin for knife with support for grouping matches based on attributes.*

## Introduction

Partial search only returns the the part of the json objects you specify instead of returning the complete objecttree and filter client side as the original search plugin does. This makes searching much much faster for large data.
**partial_search.rb** is copied from the partial_search cookbook from opscode.

201 nodes:

  time knife search node 'name:\*' -a languages.php.version
  real	0m13.881s

  time knife psearch node 'name:\*' -a languages.php.version
  real	0m3.592s

In addition psearch has a group functionalty that enables you to group host by some attribute.

## Requirements

Psearch uses the new partial search api included in chef-server 11. 

##Example searches

###Search and group results

**List all nodes with PHP installed and group output based on PHP version**

`knife psearch node "name:*" -g languages.php.version`


**Same search, but also include servers which do not have the languages.php.version attribute set**

  `knife psearch node "name:*" -g languages.php.version -n`

###Standard Partial searches

By default psearch will return the node name on all searches.
You can specify additional attributes to include with the -a flag.
Multiple attributes is separated by a comma.

**Show ipaddress and roles on all nodes**

`knife psearch node "name:*" -a ipaddress,roles`

##Installation

Copy psearch.rb, partial_search.rb to $HOME/.chef/plugins
